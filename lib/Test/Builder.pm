package Test::Builder;

use 5.008001;
use TB2::Mouse;
use TB2::Types;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use TB2::OnlyOnePlan;
use TB2::Events;
use TB2::TestState;

with 'TB2::CanDupFilehandles',
     'TB2::CanTry',
     'TB2::CanLoad',
     'TB2::CanOpen',
     'TB2::HasObjectID';



=head1 NAME

Test::Builder - Backend for building test libraries

=head1 SYNOPSIS

  package My::Test::Module;
  use base 'Test::Builder::Module';

  my $CLASS = __PACKAGE__;

  sub ok {
      my($test, $name) = @_;
      my $tb = $CLASS->builder;

      $tb->ok($test, $name);
  }


=head1 DESCRIPTION

Test::Simple and Test::More have proven to be popular testing modules,
but they're not always flexible enough.  Test::Builder provides a
building block upon which to write your own test libraries I<which can
work together>.

=head2 Construction

=over 4

=item B<new>

  my $Test = Test::Builder->new;

Returns a Test::Builder object representing the current state of the
test.

Since you only run one test per program, C<new()> always returns the same
Test::Builder object.  No matter how many times you call C<new()>, you're
getting the same object.  This is called the default.  This is done so that
multiple modules share such global information as the test counter and
where test output is going.

If you want a completely new Test::Builder object different from the
default, use C<create()>.

=cut

our $Test;

sub new {
    my($class) = shift;
    $Test ||= $class->_make_default;
    return $Test;
}

# Bit of a hack to make the default TB1 object use the history default.
sub _make_default {
    my $class = shift;

    my $obj = $class->create;
    $obj->{TestState} = TB2::TestState->default;
    $obj->{TestState}->add_early_handlers(
        TB2::OnlyOnePlan->new
    );

    return $obj;
}

=item B<create>

  my $Test = Test::Builder->create;

Ok, so there can be more than one Test::Builder object and this is how
you get it.  You might use this instead of C<new()> if you're testing
a Test::Builder based module, but otherwise you probably want C<new>.

B<NOTE>: the implementation is not complete.  C<level>, for example, is
still shared amongst B<all> Test::Builder objects, even ones created using
this method.  Also, the method name may change in the future.

=cut

sub create {
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    $self->reset;

    return $self;
}


=item B<subtest>

    $builder->subtest($name, \&subtests);

See documentation of C<subtest> in Test::More.

=cut

sub subtest {
    my $self = shift;
    my($name, $subtests) = @_;

    if ('CODE' ne ref $subtests) {
        $self->croak("subtest()'s second argument must be a code ref");
    }

    $self->test_start unless $self->in_test;

    # Save the TODO state
    my $todo_state = $self->_todo_state;

    my $in_todo     = $self->in_todo;

    my %extra_args;
    if( $in_todo ) {
        $extra_args{directives} = ["todo"];
        $extra_args{reason}     = $self->todo;
    }

    $self->post_event(
        TB2::Event::SubtestStart->new(
            $self->_file_and_line,
            name        => $name,
            %extra_args
        )
    );

    # Save and clear the content of $TODO so it doesn't make all
    # the subtest's tests TODO.
    my $orig_TODO = $self->find_TODO(undef, 1, undef);
    {
        local $Test::Builder::Level = $self->{Set_Level};

        # The subtest gets its own TODO state
        $self->_reset_todo_state;

        my(undef, $error) = $self->try(sub { $subtests->() });

        die $error if $error && !eval { $error->isa("Test::Builder::Exception") };
    }

    $self->done_testing if !$self->history->done_testing;
    {
        # Don't change the exit code while doing the ending for a subtest
        my $old_setting = $self->no_change_exit_code;
        $self->no_change_exit_code(1);
        $self->_ending;
        $self->no_change_exit_code($old_setting);
    }

    # Restore TODO state
    for my $key (keys %$todo_state) {
        $self->{$key} = $todo_state->{$key};
    }

    # Restore $TODO
    $self->find_TODO(undef, 1, $orig_TODO);

    my $subtest_end = TB2::Event::SubtestEnd->new(
        $self->_file_and_line,
    );

    $self->post_event($subtest_end);

    return $subtest_end->result;
}


=item B<in_test>

    my $in_test = $builder->in_test;

Returns true if a test has started and not finished.

Testing has begun when a plan is issued or a test is run.  Testing has
ended when C<done_testing> is called or the process is exiting.

=cut

sub in_test {
    return $_[0]->history->in_test;
}

=item B<in_subtest>

  my $in_subtest = $builder->in_subtest;

Returns true if the $builder is in a subtest.

=cut

sub in_subtest {
    my $self = shift;

    return $self->history->is_subtest;
}

=item B<reset>

  $Test->reset;

Reinitializes the Test::Builder default to its original state.
Mostly useful for tests run in persistent environments where the same
test might be run multiple times in the same process.

=cut

our $Level;
my $Opened_Testhandles = 0;
sub reset {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my($self, %overrides) = @_;

    $self->level(1);

    $self->{Exported_To}    = undef;

    $self->{TestState} = TB2::TestState->create(
        early_handlers  => [TB2::OnlyOnePlan->new],
    );

    $self->use_numbers(1);
    $self->no_header(0);
    $self->no_diag(0);
    $self->no_ending(0);
    $self->no_change_exit_code(0);

    $self->_reset_todo_state;

    return;
}


=item B<test_state>

    my $state = $builder->test_state;

Returns the L<TB2::TestState> representing the test $builder is working with.

There may be other builders contributing to the same $state.

=cut

sub test_state {
    return $_[0]->{TestState};
}


=item B<formatter>

    my $formatter = $builder->formatter;

Returns the L<TB2::Formatter> being used to format test output.

=cut

use TB2::BlackHole;
my $blackhole = TB2::BlackHole->new;
sub formatter {
    return $_[0]->test_state->formatters->[0] || $blackhole;
}


=item B<set_formatter>

    $builder->set_formatter( $formatter );

Change what $formatter is used to output the test.

Note that this changes the $formatter for the entire test state, not just this $builder.

=cut

sub set_formatter {
    my $self      = shift;
    my $formatter = shift;

    $self->croak("No formatter given to set_formatter()") unless $formatter;
    $self->croak("Argument to set_formatter() is not a TB2::Formatter")
      unless $self->try( sub { $formatter->isa("TB2::Formatter") } );

    my $state = $self->test_state;
    $state->clear_formatters;
    $state->add_formatters($formatter);

    return;
}


=item B<history>

    my $history = $builder->history;

A convenience method to access the L<TB2::History> object associated
with the C<test_state>.

=cut

sub history {
    return $_[0]->test_state->history;
}


=item B<object_id>

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

See L<TB2::HasObjectID>

=back

=head2 Setting up tests

These methods are for setting up tests and declaring how many there
are.  You usually only want to call one of these methods.

=over 4

=item B<plan>

  $Test->plan('no_plan');
  $Test->plan( skip_all => $reason );
  $Test->plan( tests => $num_tests );

A convenient way to set up your tests.  Call this and Test::Builder
will print the appropriate headers and take the appropriate actions.

If you call C<plan()>, don't call any of the other methods below.

=cut

my %plan_cmds = (
    no_plan     => \&no_plan,
    skip_all    => \&skip_all,
    tests       => \&_plan_tests,
);

sub plan {
    my( $self, $cmd, $arg ) = @_;

    return unless $cmd;

    local $Level = $Level + 1;

    if( my $method = $plan_cmds{$cmd} ) {
        local $Level = $Level + 1;
        $self->$method($arg);
    }
    else {
        my @args = grep { defined } ( $cmd, $arg );
        $self->croak("plan() doesn't understand @args");
    }

    return 1;
}


sub _plan_tests {
    my($self, $arg) = @_;

    if($arg) {
        local $Level = $Level + 1;
        return $self->expected_tests($arg);
    }
    elsif( !defined $arg ) {
        $self->croak("Got an undefined number of tests");
    }
    else {
        $self->croak("You said to run 0 tests");
    }

    return;
}

=item B<expected_tests>

    my $max = $Test->expected_tests;
    $Test->expected_tests($max);

Gets/sets the number of tests we expect this test to run and prints out
the appropriate headers.

=cut

sub expected_tests {
    my $self = shift;
    my($max) = @_;

    if(@_) {
        $self->croak("Number of tests must be a positive integer.  You gave it '$max'")
          unless $max =~ /^\+?\d+$/;

        $self->test_start unless $self->in_test;

        $self->set_plan(
            asserts_expected => $max
        );
    }

    my $plan = $self->history->plan;
    return 0 unless $plan;
    return $plan->asserts_expected;
}

=item B<no_plan>

  $Test->no_plan;

Declares that this test will run an indeterminate number of tests.

=cut

sub no_plan {
    my($self, $arg) = @_;

    $self->test_start unless $self->in_test;

    $self->set_plan(
        no_plan => 1
    );

    return 1;
}


=item B<done_testing>

  $Test->done_testing();
  $Test->done_testing($num_tests);

Declares that you are done testing, no more tests will be run after this point.

If a plan has not yet been output, it will do so.

$num_tests is the number of tests you planned to run.  If a numbered
plan was already declared, and if this contradicts, a failing test
will be run to reflect the planning mistake.  If C<no_plan> was declared,
this will override.

If C<done_testing()> is called twice, the second call will issue a
failing test.

If C<$num_tests> is omitted, the number of tests run will be used, like
no_plan.

C<done_testing()> is, in effect, used when you'd want to use C<no_plan>, but
safer. You'd use it like so:

    $Test->ok($a == $b);
    $Test->done_testing();

Or to plan a variable number of tests:

    for my $test (@tests) {
        $Test->ok($test);
    }
    $Test->done_testing(scalar @tests);

=cut

sub done_testing {
    my($self, $num_tests) = @_;

    $self->croak("Tried to finish testing, but testing is already done")
      if !$self->in_test and $self->history->done_testing;

    if( defined $num_tests ) {
        my $expected_tests = $self->expected_tests;
        if( $expected_tests && $num_tests != $expected_tests ) {
            $self->ok(0, "planned to run $expected_tests but done_testing() expects $num_tests");
        }
        else {
            $self->set_plan( asserts_expected => $num_tests );
        }
    }
    elsif( !$self->history->plan ) {
        $self->test_start unless $self->in_test;
        $self->set_plan( no_plan => 1 );
    }

    $self->test_end;

    return 1;
}


=item B<has_plan>

  $plan = $Test->has_plan

Find out whether a plan has been defined. C<$plan> is either C<undef> (no plan
has been set), C<no_plan> (indeterminate # of tests) or an integer (the number
of expected tests).

=cut

sub has_plan {
    my $self = shift;

    my $plan = $self->history->plan;
    return undef if !defined $plan;     ## no critic

    return 'no_plan' if $plan->no_plan;

    my $want = $plan->asserts_expected;
    return $want if $want;

    return undef;                       ## no critic
}

=item B<skip_all>

  $Test->skip_all;
  $Test->skip_all($reason);

Skips all the tests, using the given C<$reason>.  Exits immediately with 0.

=cut

sub skip_all {
    my( $self, $reason ) = @_;

    $reason = defined $reason ? $reason : '';

    $self->test_start;

    $self->set_plan(
        skip            => 1,
        skip_reason     => $reason
    );

    if ( $self->history->subtest_depth ) {
        # We're in a subtest, don't exit.  Throw an exception.
        die bless { from => "skip_all" } => 'Test::Builder::Exception';
    }
    else {
        exit(0);
    }
}

=item B<exported_to>

  my $pack = $Test->exported_to;
  $Test->exported_to($pack);

Tells Test::Builder what package you exported your functions to.

This method isn't terribly useful since modules which share the same
Test::Builder object might get exported to different packages and only
the last one will be honored.

=cut

sub exported_to {
    my( $self, $pack ) = @_;

    if( defined $pack ) {
        $self->{Exported_To} = $pack;
    }
    return $self->{Exported_To};
}

=back

=head2 Running tests

These actually run the tests, analogous to the functions in Test::More.

They all return true if the test passed, false if the test failed.

C<$name> is always optional.

=over 4

=item B<ok>

  $Test->ok($test, $name);

Your basic test.  Pass if C<$test> is true, fail if $test is false.  Just
like Test::Simple's C<ok()>.

=cut

sub test_start {
    my $self = shift;

    $self->test_state->post_event(
        TB2::Event::TestStart->new( $self->_file_and_line(1) )
    );

    return;
}

sub test_end {
    my $self = shift;

    $self->test_state->post_event(
        TB2::Event::TestEnd->new( $self->_file_and_line(1) )
    );

    return;
}

sub set_plan {
    my $self = shift;

    $self->test_state->post_event(
        TB2::Event::SetPlan->new( $self->_file_and_line, @_ )
    );

    return;
}


sub post_event {
    return $_[0]->test_state->post_event($_[1]);
}

sub post_result {
    my $self = shift;
    my $result = shift;

    $self->test_start unless $self->in_test;
    $self->test_state->post_event($result);

    return;
}


sub ok {
    my( $self, $test, $name ) = @_;

    # $test might contain an object which we don't want to accidentally
    # store, so we turn it into a boolean.
    $test = $test ? 1 : 0;

    # In case $name is a string overloaded object, force it to stringify.
    $self->_unoverload_str( \$name );

    $self->diag(<<"ERR") if defined $name and $name =~ /^[\d\s]+$/;
    You named your test '$name'.  You shouldn't use numbers for your test names.
    Very confusing.
ERR

    # Capture the value of $TODO for the rest of this ok() call
    # so it can more easily be found by other routines.
    my $in_todo = $self->in_todo;

    # Calling todo() is expensive.  Only do so if we're in a TODO test.
    my $todo;
    $todo = $self->todo()               if $in_todo;
    local $self->{Todo} = $todo         if $in_todo;
    $self->_unoverload_str( \$todo )    if $in_todo;

    # Turn the test into a Result
    my( $pack, $file, $line ) = $self->caller;

    my $result = TB2::Result->new_result(
        $self->_file_and_line,
        pass            => $test ? 1 : 0,
        file            => $file,
        line            => $line,
        name            => $name,
        directives      => $in_todo ? ["todo"] : [],
        reason          => $in_todo ? $todo : undef,
    );

    # Store the Result in history making sure to make it thread safe
    $self->post_result($result);

    return $test ? 1 : 0;
}


sub _unoverload {
    my $self = shift;
    my $type = shift;

    $self->load("overload");

    foreach my $thing (@_) {
        if( $self->_is_object($$thing) ) {
            if( my $string_meth = overload::Method( $$thing, $type ) ) {
                $$thing = $$thing->$string_meth();
            }
        }
    }

    return;
}

sub _is_object {
    my( $self, $thing ) = @_;

    return $self->try( sub { ref $thing && $thing->isa('UNIVERSAL') } ) ? 1 : 0;
}

sub _unoverload_str {
    my $self = shift;

    return $self->_unoverload( q[""], @_ );
}

sub _unoverload_num {
    my $self = shift;

    $self->_unoverload( '0+', @_ );

    for my $val (@_) {
        next unless $self->_is_dualvar($$val);
        $$val = $$val + 0;
    }

    return;
}

# This is a hack to detect a dualvar such as $!
sub _is_dualvar {
    my( $self, $val ) = @_;

    # Objects are not dualvars.
    return 0 if ref $val;

    no warnings 'numeric';
    my $numval = $val + 0;
    return $numval != 0 and $numval ne $val ? 1 : 0;
}

=item B<is_eq>

  $Test->is_eq($got, $expected, $name);

Like Test::More's C<is()>.  Checks if C<$got eq $expected>.  This is the
string version.

C<undef> only ever matches another C<undef>.

=item B<is_num>

  $Test->is_num($got, $expected, $name);

Like Test::More's C<is()>.  Checks if C<$got == $expected>.  This is the
numeric version.

C<undef> only ever matches another C<undef>.

=cut

sub is_eq {
    my( $self, $got, $expect, $name ) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;

        $self->ok( $test, $name );
        $self->_is_diag( $got, 'eq', $expect ) unless $test;
        return $test;
    }

    return $self->cmp_ok( $got, 'eq', $expect, $name );
}

sub is_num {
    my( $self, $got, $expect, $name ) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;

        $self->ok( $test, $name );
        $self->_is_diag( $got, '==', $expect ) unless $test;
        return $test;
    }

    return $self->cmp_ok( $got, '==', $expect, $name );
}

sub _diag_fmt {
    my( $self, $type, $val ) = @_;

    if( defined $$val ) {
        if( $type eq 'eq' or $type eq 'ne' ) {
            # quote and force string context
            $$val = "'$$val'";
        }
        else {
            # force numeric context
            $self->_unoverload_num($val);
        }
    }
    else {
        $$val = 'undef';
    }

    return;
}

sub _is_diag {
    my( $self, $got, $type, $expect ) = @_;

    $self->_diag_fmt( $type, $_ ) for \$got, \$expect;

    local $Level = $Level + 1;
    return $self->diag(<<"DIAGNOSTIC");
         got: $got
    expected: $expect
DIAGNOSTIC

}

sub _isnt_diag {
    my( $self, $got, $type ) = @_;

    $self->_diag_fmt( $type, \$got );

    local $Level = $Level + 1;
    return $self->diag(<<"DIAGNOSTIC");
         got: $got
    expected: anything else
DIAGNOSTIC
}

=item B<isnt_eq>

  $Test->isnt_eq($got, $dont_expect, $name);

Like Test::More's C<isnt()>.  Checks if C<$got ne $dont_expect>.  This is
the string version.

=item B<isnt_num>

  $Test->isnt_num($got, $dont_expect, $name);

Like Test::More's C<isnt()>.  Checks if C<$got != $dont_expect>.  This is
the numeric version.

=cut

sub isnt_eq {
    my( $self, $got, $dont_expect, $name ) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;

        $self->ok( $test, $name );
        $self->_isnt_diag( $got, 'ne' ) unless $test;
        return $test;
    }

    return $self->cmp_ok( $got, 'ne', $dont_expect, $name );
}

sub isnt_num {
    my( $self, $got, $dont_expect, $name ) = @_;
    local $Level = $Level + 1;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;

        $self->ok( $test, $name );
        $self->_isnt_diag( $got, '!=' ) unless $test;
        return $test;
    }

    return $self->cmp_ok( $got, '!=', $dont_expect, $name );
}

=item B<like>

  $Test->like($thing, qr/$regex/, $name);
  $Test->like($thing, '/$regex/', $name);

Like Test::More's C<like()>.  Checks if $thing matches the given C<$regex>.

=item B<unlike>

  $Test->unlike($thing, qr/$regex/, $name);
  $Test->unlike($thing, '/$regex/', $name);

Like Test::More's C<unlike()>.  Checks if $thing B<does not match> the
given C<$regex>.

=cut

sub like {
    my( $self, $thing, $regex, $name ) = @_;

    local $Level = $Level + 1;
    return $self->_regex_ok( $thing, $regex, '=~', $name );
}

sub unlike {
    my( $self, $thing, $regex, $name ) = @_;

    local $Level = $Level + 1;
    return $self->_regex_ok( $thing, $regex, '!~', $name );
}

=item B<cmp_ok>

  $Test->cmp_ok($thing, $type, $that, $name);

Works just like Test::More's C<cmp_ok()>.

    $Test->cmp_ok($big_num, '!=', $other_big_num);

=cut

my %numeric_cmps = map { ( $_, 1 ) } ( "<", "<=", ">", ">=", "==", "!=", "<=>" );

# Bad, these are not comparison operators. Should we include more?
my %cmp_ok_bl = map { ( $_, 1 ) } ( "=", "+=", ".=", "x=", "^=", "|=", "||=", "&&=", "...");

sub cmp_ok {
    my( $self, $got, $type, $expect, $name ) = @_;

    if ($cmp_ok_bl{$type}) {
        $self->croak("$type is not a valid comparison operator in cmp_ok()");
    }

    my $test;
    my $error;
    {
        ## no critic (BuiltinFunctions::ProhibitStringyEval)

        local( $@, $!, $SIG{__DIE__} );    # isolate eval

        my($pack, $file, $line) = $self->caller();

        # This is so that warnings come out at the caller's level
        $test = eval qq[
#line $line "(eval in cmp_ok) $file"
\$got $type \$expect;
];
        $error = $@;
    }
    local $Level = $Level + 1;
    my $ok = $self->ok( $test, $name );

    # Treat overloaded objects as numbers if we're asked to do a
    # numeric comparison.
    my $unoverload
      = $numeric_cmps{$type}
      ? '_unoverload_num'
      : '_unoverload_str';

    $self->diag(<<"END") if $error;
An error occurred while using $type:
------------------------------------
$error
------------------------------------
END

    unless($ok) {
        $self->$unoverload( \$got, \$expect );

        if( $type =~ /^(eq|==)$/ ) {
            $self->_is_diag( $got, $type, $expect );
        }
        elsif( $type =~ /^(ne|!=)$/ ) {
            $self->_isnt_diag( $got, $type );
        }
        else {
            $self->_cmp_diag( $got, $type, $expect );
        }
    }
    return $ok;
}

sub _cmp_diag {
    my( $self, $got, $type, $expect ) = @_;

    $got    = defined $got    ? "'$got'"    : 'undef';
    $expect = defined $expect ? "'$expect'" : 'undef';

    local $Level = $Level + 1;
    return $self->diag(<<"DIAGNOSTIC");
    $got
        $type
    $expect
DIAGNOSTIC
}

sub _caller_context {
    my $self = shift;

    my( $pack, $file, $line ) = $self->caller(1);

    my $code = '';
    $code .= "#line $line $file\n" if defined $file and defined $line;

    return $code;
}

=back


=head2 Other Testing Methods

These are methods which are used in the course of writing a test but are not themselves tests.

=over 4

=item B<BAIL_OUT>

    $Test->BAIL_OUT($reason);

Indicates to the Test::Harness that things are going so badly all
testing should terminate.  This includes running any additional test
scripts.

It will exit with 255.

=cut

sub BAIL_OUT {
    my( $self, $reason ) = @_;

    $self->test_state->post_event(
        TB2::Event::Abort->new( reason => $reason )
    );

    # Get out of any subtest we might be in
    while( $self->history->is_subtest ) {
        $self->test_state->post_event(
            TB2::Event::SubtestEnd->new(
                $self->_file_and_line
            )
        );
    }

    # If this is the top, kill the process.
    exit 255;
}

=for deprecated
BAIL_OUT() used to be BAILOUT()

=cut

{
    no warnings 'once';
    *BAILOUT = \&BAIL_OUT;
}

=item B<skip>

    $Test->skip;
    $Test->skip($why);

Skips the current test, reporting C<$why>.

=cut

sub skip {
    my( $self, $why ) = @_;
    $why ||= '';
    $self->_unoverload_str( \$why );

#    lock( $self->history );

    my($pack, $file, $line) = $self->caller;
    my $result = TB2::Result->new_result(
        $self->_file_and_line,
        pass      => 1,
        directives=> ['skip'],
        reason    => $why,
        line      => $line,
        file      => $file,
    );
    $self->post_result($result);

    return 1;
}

=item B<todo_skip>

  $Test->todo_skip;
  $Test->todo_skip($why);

Like C<skip()>, only it will declare the test as failing and TODO.  Similar
to

    print "not ok $tnum # TODO $why\n";

=cut

sub todo_skip {
    my( $self, $why ) = @_;
    $why ||= '';

#    lock( $self->history );

    my($pack, $file, $line) = $self->caller;
    my $result = TB2::Result->new_result(
        $self->_file_and_line,
        pass            => 0,
        directives      => ["todo", "skip"],
        reason          => $why,
        file            => $file,
        line            => $line,
    );
    $self->post_result($result);

    return 1;
}

=begin _unimplemented

=item B<skip_rest>

  $Test->skip_rest;
  $Test->skip_rest($reason);

Like C<skip()>, only it skips all the rest of the tests you plan to run
and terminates the test.

If you're running under C<no_plan>, it skips once and terminates the
test.

=end _unimplemented

=back


=head2 Test building utility methods

These methods are useful when writing your own test methods.

=over 4

=item B<maybe_regex>

  $Test->maybe_regex(qr/$regex/);
  $Test->maybe_regex('/$regex/');

This method used to be useful back when Test::Builder worked on Perls
before 5.6 which didn't have qr//.  Now it's pretty useless.

Convenience method for building testing functions that take regular
expressions as arguments.

Takes a quoted regular expression produced by C<qr//>, or a string
representing a regular expression.

Returns a Perl value which may be used instead of the corresponding
regular expression, or C<undef> if its argument is not recognised.

For example, a version of C<like()>, sans the useful diagnostic messages,
could be written as:

  sub laconic_like {
      my ($self, $thing, $regex, $name) = @_;
      my $usable_regex = $self->maybe_regex($regex);
      die "expecting regex, found '$regex'\n"
          unless $usable_regex;
      $self->ok($thing =~ m/$usable_regex/, $name);
  }

=cut

sub maybe_regex {
    my( $self, $regex ) = @_;
    my $usable_regex = undef;

    return $usable_regex unless defined $regex;

    my( $re, $opts );

    # Check for qr/foo/
    if( _is_qr($regex) ) {
        $usable_regex = $regex;
    }
    # Check for '/foo/' or 'm,foo,'
    elsif(( $re, $opts )        = $regex =~ m{^ /(.*)/ (\w*) $ }sx              or
          ( undef, $re, $opts ) = $regex =~ m,^ m([^\w\s]) (.+) \1 (\w*) $,sx
    )
    {
        $usable_regex = length $opts ? "(?$opts)$re" : $re;
    }

    return $usable_regex;
}

sub _is_qr {
    my $regex = shift;

    # is_regexp() checks for regexes in a robust manner, say if they're
    # blessed.
    return re::is_regexp($regex) if defined &re::is_regexp;
    return ref $regex eq 'Regexp';
}

sub _regex_ok {
    my( $self, $thing, $regex, $cmp, $name ) = @_;

    my $ok           = 0;
    my $usable_regex = $self->maybe_regex($regex);
    unless( defined $usable_regex ) {
        local $Level = $Level + 1;
        $ok = $self->ok( 0, $name );
        $self->diag("    '$regex' doesn't look much like a regex to me.");
        return $ok;
    }

    {
        ## no critic (BuiltinFunctions::ProhibitStringyEval)

        my $test;
        my $context = $self->_caller_context;

        # isolate eval
        local $@;
        local $!;
        local $SIG{__DIE__};

        $test = eval $context . q{$test = $thing =~ /$usable_regex/ ? 1 : 0};

        $test = !$test if $cmp eq '!~';

        local $Level = $Level + 1;
        $ok = $self->ok( $test, $name );
    }

    unless($ok) {
        $thing = defined $thing ? "'$thing'" : 'undef';
        my $match = $cmp eq '=~' ? "doesn't match" : "matches";

        local $Level = $Level + 1;
        $self->diag( sprintf <<'DIAGNOSTIC', $thing, $match, $regex );
                  %s
    %13s '%s'
DIAGNOSTIC

    }

    return $ok;
}


=item B<is_fh>

    my $is_fh = $Test->is_fh($thing);

Determines if the given C<$thing> can be used as a filehandle.

=cut

sub is_fh {
    my $self     = shift;
    my $maybe_fh = shift;
    return 0 unless defined $maybe_fh;

    return 1 if ref $maybe_fh  eq 'GLOB';    # its a glob ref
    return 1 if ref \$maybe_fh eq 'GLOB';    # its a glob

    return $self->try(sub { $maybe_fh->isa("IO::Handle") }) ||
           $self->try(sub { tied($maybe_fh)->can('TIEHANDLE') });
}

=back


=head2 Test style

=over 4

=item B<level>

    $Test->level($how_high);

How far up the call stack should C<$Test> look when reporting where the
test failed.

Defaults to 1.

Setting L<$Test::Builder::Level> overrides.  This is typically useful
localized:

    sub my_ok {
        my $test = shift;

        local $Test::Builder::Level = $Test::Builder::Level + 1;
        $TB->ok($test);
    }

To be polite to other functions wrapping your own you usually want to increment C<$Level> rather than set it to a constant.

=cut

sub level {
    my( $self, $level ) = @_;

    if( defined $level ) {
        $self->{Set_Level} = $level;
        $Level = $level;
    }
    return $Level;
}

=item B<use_numbers>

    $Test->use_numbers($on_or_off);

Whether or not the test should output numbers.  That is, this if true:

  ok 1
  ok 2
  ok 3

or this if false

  ok
  ok
  ok

Most useful when you can't depend on the test output order, such as
when threads or forking is involved.

Defaults to on.

=cut

sub use_numbers {
    my( $self, $use_nums ) = @_;

    my $formatter = $self->formatter;

    return unless $formatter->can("use_numbers");

    if( defined $use_nums ) {
        $formatter->use_numbers($use_nums);
    }
    return $formatter->use_numbers;
}

=item B<no_diag>

    $Test->no_diag($no_diag);

If set true no diagnostics nor notes will be displayed.  This includes
calls to C<diag()> and C<note()>.

=cut

sub no_diag {
    my $self = shift;

    my $formatter = $self->formatter;
    return unless $formatter->can("show_logs");

    if( @_ ) {
        my $no = shift;
        $self->formatter->show_logs(!$no);
    }

    return !$self->formatter->show_logs;
}


=item B<no_ending>

    $Test->no_ending($no_ending);

Normally, Test::Builder does some extra diagnostics when the test
ends.  It also changes the exit code as described below.

If this is true, none of that will be done.

=cut

sub no_ending {
    my $self = shift;

    my $formatter = $self->formatter;
    return unless $formatter->can("show_ending_commentary");

    if( @_ ) {
        my $no = shift;
        $self->{No_Ending} = $no;
        $self->formatter->show_ending_commentary(!$no);
    }

    return $self->{No_Ending};
}


=item B<no_header>

    $Test->no_header($no_header);

If set to true, no "1..N" header will be printed.

=cut

sub no_header {
    my $self = shift;

    my $formatter = $self->formatter;
    return unless $formatter->can("show_header");

    if( @_ ) {
        my $no = shift;
        $self->formatter->show_header(!$no);
    }

    return !$self->formatter->show_header;
}


=item B<no_change_exit_code>

    $tb->no_change_exit_code($no_change);

If true, Test::Builder will not change the process' exit code.

See L<test_exit_code> for details.

=cut

sub no_change_exit_code {
    my $self = shift;

    if( @_ ) {
        my $no = shift;
        $self->{Change_Exit_Code} = !$no;
    }

    return !$self->{Change_Exit_Code};
}

=back

=head2 Output

Controlling where the test output goes.

It's ok for your test to change where STDOUT and STDERR point to,
Test::Builder's default output settings will not be affected.

=over 4

=item B<diag>

    $Test->diag(@msgs);

Prints out the given C<@msgs>.  Like C<print>, arguments are simply
appended together.

Normally, it uses the C<failure_output()> handle, but if this is for a
TODO test, the C<output()> handle is used.

Output will be indented and marked with a # so as not to interfere
with test output.  A newline will be put on the end if there isn't one
already.

We encourage using this rather than calling print directly.

Returns false.  Why?  Because C<diag()> is often used in conjunction with
a failing test (C<ok() || diag()>) it "passes through" the failure.

    return ok(...) || diag(...);

=for blame transfer
Mark Fowler <mark@twoshortplanks.com>

=cut

sub diag {
    my $self = shift;

    return unless @_;
    return $self->note(@_) if $self->in_todo;

    $self->test_state->post_event(
        TB2::Event::Log->new(
            $self->_file_and_line,
            message     => $self->_join_message(@_),
            level       => 'warning'
        )
    );

    return;
}

=item B<note>

    $Test->note(@msgs);

Like C<diag()>, but it prints to the C<output()> handle so it will not
normally be seen by the user except in verbose mode.

=cut

sub note {
    my $self = shift;

    return unless @_;

    $self->test_state->post_event(
        TB2::Event::Log->new(
            $self->_file_and_line,
            message     => $self->_join_message(@_),
            level       => 'info'
        )
    );

    return;
}

sub _join_message {
    my $self = shift;
    return join '', map { defined($_) ? $_ : 'undef' } @_;
}


=item B<explain>

    my @dump = $Test->explain(@msgs);

Will dump the contents of any references in a human readable format.
Handy for things like...

    is_deeply($have, $want) || diag explain $have;

or

    is_deeply($have, $want) || note explain $have;

=cut

sub explain {
    my $self = shift;

    return map {
        ref $_
          ? do {
            $self->load("Data::Dumper");

            my $dumper = Data::Dumper->new( [$_] );
            $dumper->Indent(1)->Terse(1);
            $dumper->Sortkeys(1) if $dumper->can("Sortkeys");
            $dumper->Dump;
          }
          : $_
    } @_;
}


=item B<output>

=item B<failure_output>

    my $filehandle = $Test->output;
    $Test->output($filehandle);
    $Test->output($filename);
    $Test->output(\$scalar);

These methods control where Test::Builder will print its output.
They take either an open C<$filehandle>, a C<$filename> to open and write to
or a C<$scalar> reference to append to.  It will always return a C<$filehandle>.

B<output> is where normal "ok/not ok" test output goes.

Defaults to STDOUT.

B<failure_output> is where diagnostic output on test failures and
C<diag()> goes.  It is normally not read by Test::Harness and instead is
displayed to the user.

Defaults to STDERR.

=item B<todo_output>

This method exists for backwards compatibility.

C<todo_output> was used instead of C<failure_output()> for the
diagnostics of a failing TODO test.  These will not be seen by the
user.

Now TODO tests will use C<< $builder->output >> and the TODO
filehandle cannot be set separate from C<output()>.

=cut

sub output {
    my( $self, $fh ) = @_;

    if( defined $fh ) {
        $fh = $self->_new_fh($fh);
        $self->formatter->streamer->output_fh($fh);
    }

    return $self->formatter->streamer->output_fh;
}

sub failure_output {
    my( $self, $fh ) = @_;

    if( defined $fh ) {
        $fh = $self->_new_fh($fh);
        $self->formatter->streamer->error_fh($fh);
    }

    return $self->formatter->streamer->error_fh;
}

sub todo_output {
    my( $self, $fh ) = @_;

    # There is no longer a concept of a separate TODO filehandle
    return $self->formatter->streamer->output_fh;
}

sub _new_fh {
    my $self = shift;
    my($file_or_fh) = shift;

    my $fh;
    if( $self->is_fh($file_or_fh) ) {
        $fh = $file_or_fh;
    }
    elsif( ref $file_or_fh eq 'SCALAR' ) {
        $self->try(sub { $fh = $self->open(">>", $file_or_fh) })
          or $self->croak("Can't open scalar ref $file_or_fh: $@");
    }
    else {
        $self->try(sub { $fh = $self->open(">", $file_or_fh) })
          or $self->croak("Can't open test output log $file_or_fh: $@");
        $self->autoflush($fh);
    }

    return $fh;
}


=item reset_outputs

  $tb->reset_outputs;

Resets all the output filehandles back to their defaults.

=cut

sub reset_outputs {
    my $self = shift;

    $self->formatter->reset_streamer;

    return;
}

=item carp

  $tb->carp(@message);

Warns with C<@message> but the message will appear to come from the
point where the original test function was called (C<< $tb->caller >>).

=item croak

  $tb->croak(@message);

Dies with C<@message> but the message will appear to come from the
point where the original test function was called (C<< $tb->caller >>).

=cut

sub _message_at_caller {
    my $self = shift;

    local $Level = $Level + 1;
    my( $pack, $file, $line ) = $self->caller;
    return join( "", @_ ) . " at $file line $line.\n";
}

sub carp {
    my $self = shift;
    return warn $self->_message_at_caller(@_);
}

sub croak {
    my $self = shift;
    return die $self->_message_at_caller(@_);
}


=back


=head2 Test Status and Info

=over 4

=item B<current_test>

    my $curr_test = $Test->current_test;
    $Test->current_test($num);

Gets/sets the current test number we're on.  You usually shouldn't
have to set this.

If set forward, the details of the missing tests are filled in as 'unknown'.
if set backward, the details of the intervening tests are deleted.  You
can erase history if you really want to.

=cut

sub current_test {
    my( $self, $num ) = @_;

    my $history = $self->history;

    # Being used as a getter.
    return $history->counter unless defined $num;

    # If the test counter is being pushed forward fill in the details.
    my $result_count = $history->result_count;

    if ( $num > $result_count ) {
        my $last_test_number = $result_count ? $result_count : 0;
        $history->counter($last_test_number);

        for my $test_number ( $last_test_number + 1 .. $num ) {
            my $result = TB2::Result->new_result(
                $self->_file_and_line,
                pass        => 1,
                directives  => [qw(unknown)],
                reason      => 'incrementing test number',
                test_number => $test_number
            );
            $history->accept_event( $result );
        }
    }
    # If backward, wipe history.  Its their funeral.
    elsif ( $num < $result_count ) {
        $history->result_count($num);
    }

    $history->counter($num);

    return;
}

=item B<is_passing>

   my $ok = $builder->is_passing;

Indicates if the test suite is currently passing.

More formally, it will be false if anything has happened which makes
it impossible for the test suite to pass.  True otherwise.

For example, if no tests have run C<is_passing()> will be true because
even though a suite with no tests is a failure you can add a passing
test to it and start passing.

Don't think about it too much.

=cut

sub is_passing {
    my $self = shift;

    return $self->history->can_succeed;
}


=item B<summary>

    my @tests = $Test->summary;

A simple summary of the tests so far.  True for pass, false for fail.
This is a logical pass/fail, so todos are passes.

Of course, test #1 is $tests[0], etc...

By default, this method will throw an exception unless Test::Builder has
been configured to store events.

=cut

sub summary {
    my($self) = shift;

    local $Level = $Level + 1;
    return map { $_->is_fail ? 0 : 1 } @{$self->_results};
}

=item B<name>

    my $name = $Test->name;

Returns the name of the current subtest or test.

=cut

sub name {
    my $self = shift;

    my $name = $self->in_subtest ? $self->history->subtest->name : $0;
}

=item B<details>

    my @tests = $Test->details;

Like C<summary()>, but with a lot more detail.

    $tests[$test_num - 1] = 
            { 'ok'       => is the test considered a pass?
              actual_ok  => did it literally say 'ok'?
              name       => name of the test (if any)
              type       => type of test (if any, see below).
              reason     => reason for the above (if any)
            };

'ok' is true if Test::Harness will consider the test to be a pass.

'actual_ok' is a reflection of whether or not the test literally
printed 'ok' or 'not ok'.  This is for examining the result of 'todo'
tests.

'name' is the name of the test.

'type' indicates if it was a special test.  Normal tests have a type
of ''.  Type can be one of the following:

    skip        see skip()
    todo        see todo()
    todo_skip   see todo_skip()
    unknown     see below

Sometimes the Test::Builder test counter is incremented without it
printing any test output, for example, when C<current_test()> is changed.
In these cases, Test::Builder doesn't know the result of the test, so
its type is 'unknown'.  These details for these tests are filled in.
They are considered ok, but the name and actual_ok is left C<undef>.

For example "not ok 23 - hole count # TODO insufficient donuts" would
result in this structure:

    $tests[22] =    # 23 - 1, since arrays start from 0.
      { ok        => 1,   # logically, the test passed since its todo
        actual_ok => 0,   # in absolute terms, it failed
        name      => 'hole count',
        type      => 'todo',
        reason    => 'insufficient donuts'
      };

By default, this test will throw an exception unless Test::Builder has
been configured to store events.

=cut

# Get $self->history->results and rethrow the error if results are
# turned off so its at the point of the caller of details() or
# summary().
sub _results {
    my $self = shift;

    my $history = $self->history;

    return $history->results if $history->store_events;

    local $Level = $Level + 1;

    $self->croak(<<ERROR);
Results are not stored by default (saves memory).  Consider using the
statistical methods of the TB2::History object instead, accessible
as Test::Builder->history.
ERROR

    return;
}

sub details {
    my $self = shift;

    local $Level = $Level + 1;
    return map { $self->_result_to_hash($_) } @{$self->_results};
}

sub _result_to_hash {
    my $self = shift;
    my $result = shift;

    my $types = $result->types;
    my $type = $result->type eq 'todo_skip' ? "todo_skip"        :
               $types->{unknown}            ? "unknown"          :
               $types->{todo}               ? "todo"             :
               $types->{skip}               ? "skip"             :
                                            ""                 ;

    my $actual_ok = $types->{unknown} ? undef : $result->literal_pass;

    return {
        'ok'       => $result->is_fail ? 0 : 1,
        actual_ok  => $actual_ok,
        name       => $result->name || "",
        type       => $type,
        reason     => $result->reason || "",
    };
}

=item B<todo>

    my $todo_reason = $Test->todo;
    my $todo_reason = $Test->todo($pack);

If the current tests are considered "TODO" it will return the reason,
if any.  This reason can come from a C<$TODO> variable or the last call
to C<todo_start()>.

Since a TODO test does not need a reason, this function can return an
empty string even when inside a TODO block.  Use C<< $Test->in_todo >>
to determine if you are currently inside a TODO block.

C<todo()> is about finding the right package to look for C<$TODO> in.  It's
pretty good at guessing the right package to look at.  It first looks for
the caller based on C<$Level + 1>, since C<todo()> is usually called inside
a test function.  As a last resort it will use C<exported_to()>.

Sometimes there is some confusion about where todo() should be looking
for the C<$TODO> variable.  If you want to be sure, tell it explicitly
what $pack to use.

=cut

sub todo {
    my( $self, $pack ) = @_;

    return $self->{Todo} if defined $self->{Todo};

    local $Level = $Level + 1;
    my $todo = $self->find_TODO($pack);
    return $todo if defined $todo;

    return '';
}

=item B<find_TODO>

    my $todo_reason = $Test->find_TODO();
    my $todo_reason = $Test->find_TODO($pack);

Like C<todo()> but only returns the value of C<$TODO> ignoring
C<todo_start()>.

Can also be used to set C<$TODO> to a new value while returning the
old value:

    my $old_reason = $Test->find_TODO($pack, 1, $new_reason);

=cut

sub find_TODO {
    my( $self, $pack, $set, $new_value ) = @_;

    $pack = $pack || $self->caller(1) || $self->exported_to;
    return unless $pack;

    my $todo = do {
        no strict 'refs';    ## no critic
        no warnings 'once';
        \${ $pack.'::TODO'};
    };
    my $old_value = $$todo;
    $set and $$todo = $new_value;
    return $old_value;
}

=item B<in_todo>

    my $in_todo = $Test->in_todo;

Returns true if the test is currently inside a TODO block.

=cut

sub in_todo {
    my $self = shift;

    local $Level = $Level + 1;
    return( defined $self->{Todo} || $self->find_TODO ) ? 1 : 0;
}

=item B<todo_start>

    $Test->todo_start();
    $Test->todo_start($message);

This method allows you declare all subsequent tests as TODO tests, up until
the C<todo_end> method has been called.

The C<TODO:> and C<$TODO> syntax is generally pretty good about figuring out
whether or not we're in a TODO test.  However, often we find that this is not
possible to determine (such as when we want to use C<$TODO> but
the tests are being executed in other packages which can't be inferred
beforehand).

Note that you can use this to nest "todo" tests

 $Test->todo_start('working on this');
 # lots of code
 $Test->todo_start('working on that');
 # more code
 $Test->todo_end;
 $Test->todo_end;

This is generally not recommended, but large testing systems often have weird
internal needs.

We've tried to make this also work with the TODO: syntax, but it's not
guaranteed and its use is also discouraged:

 TODO: {
     local $TODO = 'We have work to do!';
     $Test->todo_start('working on this');
     # lots of code
     $Test->todo_start('working on that');
     # more code
     $Test->todo_end;
     $Test->todo_end;
 }

Pick one style or another of "TODO" to be on the safe side.

=cut

sub todo_start {
    my $self = shift;
    my $message = @_ ? shift : '';

    $self->{Start_Todo}++;
    if( $self->in_todo ) {
        push @{ $self->{Todo_Stack} } => $self->todo;
    }
    $self->{Todo} = $message;

    return;
}

=item C<todo_end>

 $Test->todo_end;

Stops running tests as "TODO" tests.  This method is fatal if called without a
preceding C<todo_start> method call.

=cut

sub todo_end {
    my $self = shift;

    if( !$self->{Start_Todo} ) {
        $self->croak('todo_end() called without todo_start()');
    }

    $self->{Start_Todo}--;

    if( $self->{Start_Todo} && @{ $self->{Todo_Stack} } ) {
        $self->{Todo} = pop @{ $self->{Todo_Stack} };
    }
    else {
        delete $self->{Todo};
    }

    return;
}


my @Todo_Keys = qw(Start_Todo Todo_Stack Todo);
sub _todo_state {
    my $self = shift;

    my %todo_state;
    for my $key (@Todo_Keys) {
        $todo_state{$key} = $self->{$key};
    }

    return \%todo_state;
}

sub _reset_todo_state {
    my $self = shift;

    $self->{Todo}       = undef;
    $self->{Todo_Stack} = [];
    $self->{Start_Todo} = 0;

    return;
}


=item B<caller>

    my $package = $Test->caller;
    my($pack, $file, $line) = $Test->caller;
    my($pack, $file, $line) = $Test->caller($height);

Like the normal C<caller()>, except it reports according to your C<level()>.

C<$height> will be added to the C<level()>.

If C<caller()> winds up off the top of the stack it report the highest context.

=cut

sub caller {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my( $self, $height ) = @_;
    $height ||= 0;

    my $level = $self->level + $height + 1;
    my @caller;
    do {
        @caller = CORE::caller( $level );
        $level--;
    } until @caller;
    return wantarray ? @caller : $caller[0];
}


# A convenience method to pass context into Event->new
sub _file_and_line {
    my( $self, $height ) = @_;
    $height ||= 0;

    my($file, $line) = ($self->caller($height + 1))[1,2];
    return ( file => $file, line => $line );
}

=back

=begin _private

=over 4

=item B<_sanity_check>

  $self->_sanity_check();

Runs a bunch of end of test sanity checks to make sure reality came
through ok.  If anything is wrong it will die with a fairly friendly
error message.

=cut

#'#
sub _sanity_check {
    my $self = shift;

    $self->_whoa( $self->current_test < 0, 'Says here you ran a negative number of tests!' );
    $self->_whoa( $self->current_test != $self->history->result_count,
        'Somehow you got a different number of results than tests ran!' );

    return;
}

=item B<_whoa>

  $self->_whoa($check, $description);

A sanity check, similar to C<assert()>.  If the C<$check> is true, something
has gone horribly wrong.  It will die with the given C<$description> and
a note to contact the author.

=cut

sub _whoa {
    my( $self, $check, $desc ) = @_;
    if($check) {
        local $Level = $Level + 1;
        $self->croak(<<"WHOA");
WHOA!  $desc
This should never happen!  Please contact the author immediately!
WHOA
    }

    return;
}

=item B<_my_exit>

  _my_exit($exit_num);

Perl seems to have some trouble with exiting inside an C<END> block.
5.6.1 does some odd things.  Instead, this function edits C<$?>
directly.  It should B<only> be called from inside an C<END> block.
It doesn't actually exit, that's your job.

=cut

sub _my_exit {
    $? = $_[0];    ## no critic (Variables::RequireLocalizedPunctuationVars)

    return 1;
}

=back

=end _private

=cut

sub _ending {
    my $self = shift;
    return if $self->no_ending;

    my $history = $self->history;
    my $plan    = $history->plan;

    # They never set a plan nor ran a test.
    return if !$plan && !$history->result_count;

    # Forked children often run fragments of tests.
    my $in_child = $self->history->is_child_process;

    # Forks often run fragments of tests, so don't do any ending
    # processing
    return if $in_child;

    # End the stream unless we (or somebody else) already ended it
    $self->test_end if $history->in_test;

    my $new_exit_code = $self->test_exit_code($?);
    _my_exit($new_exit_code);
}


=head3 test_exit_code

    my $new_exit_code = $tb->test_exit_code($?);

Determine the exit code of the process to reflect if the test
succeeded or not.

This does not actually change the exit code.

If L<no_change_exit_code> is set true, the exit code will not be
changed.  $new_exit_code will be identical to the input.

See L<EXIT CODES> for details.

=cut

sub test_exit_code {
    my $self = shift;
    my $real_exit_code = @_ ? shift : $?;

    return $real_exit_code if $self->no_change_exit_code;

    my $history = $self->history;
    my $plan    = $history->plan;

    # They never set a plan nor ran a test.
    return $real_exit_code if !$plan && !$history->result_count;

    # The test bailed out.
    if( $history->abort ) {
            $self->diag(<<"FAIL");
Looks like your test bailed out.
FAIL
        return 255;
    }
    # Some tests were run...
    elsif( $history->result_count ) {
        # ...but we exited with non-zero
        if($real_exit_code) {
            $self->diag(<<"FAIL");
Looks like your test exited with $real_exit_code just after @{[ $self->current_test ]}.
FAIL
            return $real_exit_code;
        }
        # Extra tests
        elsif(my $num_failed = $history->fail_count) {
            return $num_failed <= 254 ? $num_failed : 254;
        }
        # Wrong number of tests
        elsif( $plan && !$plan->no_plan && $self->current_test != $plan->asserts_expected ) {
            return 255;
        }
        else {
            return $real_exit_code;
        }
    }
    # Everything was skipped
    elsif( $plan->skip ) {
        if( $real_exit_code ) {
            $self->diag(<<"FAIL");
Looks like your test skipped but exited with $real_exit_code.
FAIL
        }

        return $real_exit_code;
    }
    # We died before running any tests
    elsif( $real_exit_code ) {
        $self->diag(<<"FAIL");
Looks like your test exited with $real_exit_code before it could output anything.
FAIL
        return $real_exit_code;
    }
    # Dunno what happened
    else {
        return 255;
    }

    $self->_whoa( 1, "We fell off the end of test_exit_code!" );
}

END {
    $Test->_ending if defined $Test;
}

=head1 EXIT CODES

If all your tests passed, Test::Builder will exit with zero (which is
normal).  If anything failed it will exit with how many failed.  If
you run less (or more) tests than you planned, the missing (or extras)
will be considered failures.  If no tests were ever run Test::Builder
will throw a warning and exit with 255.  If the test died, even after
having successfully completed all its tests, it will still be
considered a failure and will exit with 255.

So the exit codes are...

    0                   all tests successful
    255                 test died or all passed but wrong # of tests run
    any other number    how many failed (including missing or extras)

If you fail more than 254 tests, it will be reported as 254.

This behavior can be turned off with L<no_change_exit_code>.

=head1 THREADS

In perl 5.8.1 and later, Test::Builder is thread-safe.  The test
number is shared amongst all threads.  This means if one thread sets
the test number using C<current_test()> they will all be effected.

While versions earlier than 5.8.1 had threads they contain too many
bugs to support.

Test::Builder is only thread-aware if threads.pm is loaded I<before>
Test::Builder.

=head1 MEMORY

An informative hash, accessible via C<<details()>>, is stored for each
test you perform.  So memory usage will scale linearly with each test
run. Although this is not a problem for most test suites, it can
become an issue if you do large (hundred thousands to million)
combinatorics tests in the same run.

In such cases, you are advised to either split the test file into smaller
ones, or use a reverse approach, doing "normal" (code) compares and
triggering fail() should anything go unexpected.

Future versions of Test::Builder will have a way to turn history off.


=head1 EXAMPLES

CPAN can provide the best examples.  Test::Simple, Test::More,
Test::Exception and Test::Differences all use Test::Builder.

=head1 SEE ALSO

Test::Simple, Test::More, Test::Harness

=head1 AUTHORS

Original code by chromatic, maintained by Michael G Schwern
E<lt>schwern@pobox.comE<gt>

=head1 COPYRIGHT

Copyright 2002-2012 by chromatic E<lt>chromatic@wgz.orgE<gt> and
                       Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/>

=cut

1;

