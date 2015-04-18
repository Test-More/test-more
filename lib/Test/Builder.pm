package Test::Builder;

use 5.008001;
use strict;
use warnings;

our $VERSION = '1.301001_105';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


use Test::Stream 1.301001 ();
use Test::Stream::Hub;
use Test::Stream::Toolset;
use Test::Stream::Context;
use Test::Stream::Carp qw/confess/;
use Test::Stream::Meta qw/MODERN/;

use Test::Stream::Util qw/try protect unoverload_str is_regex/;
use Scalar::Util qw/blessed reftype/;

use Test::More::Tools;

BEGIN {
    my $meta = Test::Stream::Meta->is_tester('main');
    Test::Stream->shared->set_use_legacy(1)
        unless $meta && $meta->{+MODERN};
}

# The mostly-singleton, and other package vars.
our $Test  = Test::Builder->new;
our $_ORIG_Test = $Test;
our $Level = 1;

sub ctx {
    my $self = shift || die "No self in context";
    my ($add) = @_;
    my $ctx = Test::Stream::Context::context(2 + ($add || 0), $self->{hub});
    if (defined $self->{Todo}) {
        $ctx->set_in_todo(1);
        $ctx->set_todo($self->{Todo});
        $ctx->set_diag_todo(1);
    }
    return $ctx;
}

sub hub {
    my $self = shift;
    return $self->{hub} || Test::Stream->shared;
}

sub depth { $_[0]->{depth} || 0 }

# This is only for unit tests at this point.
sub _ending {
    my $self = shift;
    my ($ctx) = @_;
    require Test::Stream::ExitMagic;
    $self->{hub}->set_no_ending(0);
    Test::Stream::ExitMagic->new->do_magic($self->{hub}, $ctx);
}


####################
# {{{ Constructors #
####################

sub new {
    my $class  = shift;
    my %params = @_;
    $Test ||= $class->create(shared_hub => 1, init => 1);

    return $Test;
}

sub create {
    my $class  = shift;
    my %params = @_;

    my $self = bless {}, $class;
    $self->reset(%params);

    return $self;
}

# Copy an object, currently a shallow.
# This does *not* bless the destination.  This keeps the destructor from
# firing when we're just storing a copy of the object to restore later.
sub _copy {
    my ($src, $dest) = @_;
    %$dest = %$src;
    return;
}

####################
# }}} Constructors #
####################

#############################
# {{{ Children and subtests #
#############################

sub subtest {
    my $self = shift;
    my $ctx = $self->ctx();
    require Test::Stream::Subtest;
    return Test::Stream::Subtest::subtest(@_);
}

sub child {
    my( $self, $name ) = @_;

    my $ctx = $self->ctx;

    if ($self->{child}) {
        my $cname = $self->{child}->{Name};
        $ctx->throw("You already have a child named ($cname) running");
    }

    $name ||= "Child of " . $self->{Name};
    my $hub = $self->{hub} || Test::Stream->shared;
    $ctx->subtest_start($name, parent_todo => $ctx->in_todo);

    my $child = bless {
        %$self,
        '?' => $?,
        parent => $self,
    };

    $? = 0;
    $child->{Name} = $name;
    $self->{child} = $child;
    Scalar::Util::weaken($self->{child});

    return $child;
}

sub finalize {
    my $self = shift;

    return unless $self->{parent};

    my $ctx = $self->ctx;

    if ($self->{child}) {
        my $cname = $self->{child}->{Name};
        $ctx->throw("Can't call finalize() with child ($cname) active");
    }

    $self->_ending($ctx);
    my $passing = $ctx->hub->is_passing;
    my $count = $ctx->hub->count;
    my $name = $self->{Name};

    my $hub = $self->{hub} || Test::Stream->shared;

    my $parent = $self->parent;
    $self->{parent}->{child} = undef;
    $self->{parent} = undef;

    $? = $self->{'?'};

    my $st = $ctx->subtest_stop($name);

    $parent->ctx->send_event(
        'Subtest',
        name         => $st->{name},
        state        => $st->{state},
        events       => $st->{events},
        exception    => $st->{exception},
        early_return => $st->{early_return},
        delayed      => $st->{delayed},
        instant      => $st->{instant},
    );
}

sub in_subtest {
    my $self = shift;
    my $ctx = $self->ctx;
    return scalar @{$ctx->hub->subtests};
}

sub parent { $_[0]->{parent} }
sub name   { $_[0]->{Name} }

sub DESTROY {
    my $self = shift;
    return unless $self->{parent};
    return if $self->{Skip_All};
    $self->{parent}->is_passing(0);
    my $name = $self->{Name};
    die "Child ($name) exited without calling finalize()";
}

#############################
# }}} Children and subtests #
#############################

#####################################
# {{{ stuff for TODO status #
#####################################

sub find_TODO {
    my ($self, $pack, $set, $new_value) = @_;

    unless ($pack) {
        if (my $ctx = Test::Stream::Context->peek) {
            $pack = $ctx->package;
            my $old = $ctx->todo;
            $ctx->set_todo($new_value) if $set;
            return $old;
        }

        $pack = $self->exported_to || return;
    }

    no strict 'refs';    ## no critic
    no warnings 'once';
    my $old_value = ${$pack . '::TODO'};
    $set and ${$pack . '::TODO'} = $new_value;
    return $old_value;
}

sub todo {
    my ($self, $pack) = @_;

    return $self->{Todo} if defined $self->{Todo};

    my $ctx = $self->ctx;

    my $todo = $self->find_TODO($pack);
    return $todo if defined $todo;

    return '';
}

sub in_todo {
    my $self = shift;

    my $ctx = $self->ctx;
    return 1 if $ctx->in_todo;

    return (defined $self->{Todo} || $self->find_TODO) ? 1 : 0;
}

sub todo_start {
    my $self = shift;
    my $message = @_ ? shift : '';

    $self->{Start_Todo}++;
    if ($self->in_todo) {
        push @{$self->{Todo_Stack}} => $self->todo;
    }
    $self->{Todo} = $message;

    return;
}

sub todo_end {
    my $self = shift;

    if (!$self->{Start_Todo}) {
        $self->ctx(-1)->throw('todo_end() called without todo_start()');
    }

    $self->{Start_Todo}--;

    if ($self->{Start_Todo} && @{$self->{Todo_Stack}}) {
        $self->{Todo} = pop @{$self->{Todo_Stack}};
    }
    else {
        delete $self->{Todo};
    }

    return;
}

#####################################
# }}} Finding Testers and Providers #
#####################################

#####################################################
# {{{ Monkeypatching support
#####################################################

my %WARNED;
our ($CTX, %ORIG);
our %EVENTS = (
    Ok   => [qw/pass name/],
    Plan => [qw/max directive reason/],
    Diag => [qw/message/],
    Note => [qw/message/],
);
{
    no strict 'refs';
    %ORIG = map { $_ => \&{$_} } qw/ok note diag plan done_testing/;
}

sub WARN_OF_OVERRIDE {
    my ($sub, $ctx) = @_;

    return unless $ctx->modern;
    my $old = $ORIG{$sub};
    # Use package instead of self, we want replaced subs, not subclass overrides.
    my $new = __PACKAGE__->can($sub);

    return if $new == $old;

    require B;
    my $o    = B::svref_2object($new);
    my $gv   = $o->GV;
    my $st   = $o->START;
    my $name = $gv->NAME;
    my $pkg  = $gv->STASH->NAME;
    my $line = $st->line;
    my $file = $st->file;

    warn <<"    EOT" unless $WARNED{"$pkg $name $file $line"}++;

*******************************************************************************
Something monkeypatched Test::Builder::$sub()!
The new sub is '$pkg\::$name' defined in $file around line $line.
In the future monkeypatching Test::Builder::$sub() may no longer work as
expected.

Test::Stream now provides tools to properly hook into events so that
monkeypatching is no longer needed.
*******************************************************************************
    EOT
}

sub _set_monkeypatch_args {
    my $self = shift;
    ($self->{monkeypatch_args}) = @_;
}

sub _set_monkeypatch_event {
    my $self = shift;
    ($self->{monkeypatch_event}) = @_;
}

# These 2 methods delete the item before returning, this is to avoid
# contamination in later events.
sub _get_monkeypatch_args {
    my $self = shift;
    return delete $self->{monkeypatch_args};
}

sub _get_monkeypatch_event {
    my $self = shift;
    return delete $self->{monkeypatch_event};
}

sub monkeypatch_event {
    my $self = shift;
    my ($event, %args) = @_;

    my @ordered;

    if ($event eq 'Plan') {
        my $max = $args{max};
        my $dir = $args{directive};
        my $msg = $args{reason};

        $dir ||= 'tests';
        $dir = 'skip_all' if $dir eq 'SKIP';
        $dir = 'no_plan'  if $dir eq 'NO PLAN';

        @ordered = ($dir, $max || $msg || ());
    }
    else {
        my $fields = $EVENTS{$event};
        $self->_set_monkeypatch_args(\%args);
        @ordered = @args{@$fields};
    }

    my $meth = lc($event);
    $self->$meth(@ordered);
    return $self->_get_monkeypatch_event;
}

#####################################################
# }}} Monkeypatching support
#####################################################

################
# {{{ Planning #
################

my %PLAN_CMDS = (
    no_plan  => 'no_plan',
    skip_all => 'skip_all',
    tests    => '_plan_tests',
);

sub plan {
    my ($self, $cmd, @args) = @_;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(plan => $ctx);

    return unless $cmd;

    if (my $method = $PLAN_CMDS{$cmd}) {
        $self->$method(@args);
    }
    else {
        my @in = grep { defined } ($cmd, @args);
        $self->ctx->throw("plan() doesn't understand @in");
    }

    return 1;
}

sub skip_all {
    my ($self, $reason) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    $self->{Skip_All} = 1;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => 0, directive => 'SKIP', reason => $reason);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
}

sub no_plan {
    my ($self, @args) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    $ctx->alert("no_plan takes no arguments") if @args;
    my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => 0, directive => 'NO PLAN');
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;

    return 1;
}

sub _plan_tests {
    my ($self, $arg) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();

    if ($arg) {
        $ctx->throw("Number of tests must be a positive integer.  You gave it '$arg'")
            unless $arg =~ /^\+?\d+$/;

        my $e = $ctx->build_event('Plan', $mp_args ? %$mp_args : (), max => $arg);
        $ctx->send($e);
        $self->_set_monkeypatch_event($e) if $mp_args;
    }
    elsif (!defined $arg) {
        $ctx->throw("Got an undefined number of tests");
    }
    else {
        $ctx->throw("You said to run 0 tests");
    }

    return;
}

sub done_testing {
    my ($self, $num_tests) = @_;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(done_testing => $ctx);

    my $out = $ctx->hub->done_testing($ctx, $num_tests);
    return $out;
}

################
# }}} Planning #
################

#############################
# {{{ Base Event Producers #
#############################

sub ok {
    my $self = shift;
    my ($test, $name) = @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(ok => $ctx);

    if ($self->{child}) {
        $self->is_passing(0);
        $ctx->throw("Cannot run test ($name) with active children");
    }

    my $e = $ctx->build_event('Ok', $mp_args ? %$mp_args : (), pass => $test, name => $name);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e, $mp_args) if $mp_args;
    return $test ? 1 : 0;
}

sub BAIL_OUT {
    my( $self, $reason ) = @_;
    $self->ctx()->bail($reason);
}

sub skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = $self->ctx();
    $ctx->set_skip($why);
    $ctx->ok(1, '');
    $ctx->set_skip(undef);
}

sub todo_skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = $self->ctx();
    $ctx->set_skip($why);
    $ctx->set_todo($why);
    $ctx->ok(0, '');
    $ctx->set_skip(undef);
    $ctx->set_todo(undef);
}

sub diag {
    my $self    = shift;
    my $msg     = join '', map { defined($_) ? $_ : 'undef' } @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(diag => $ctx);

    my $e = $ctx->build_event('Diag', $mp_args ? %$mp_args : (), message => $msg);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
    return;
}

sub note {
    my $self    = shift;
    my $msg     = join '', map { defined($_) ? $_ : 'undef' } @_;
    my $mp_args = $self->_get_monkeypatch_args;

    my $ctx = $CTX || Test::Stream::Context->peek || $self->ctx();
    WARN_OF_OVERRIDE(note => $ctx);

    my $e = $ctx->build_event('Note', $mp_args ? %$mp_args : (), message => $msg);
    $ctx->send($e);
    $self->_set_monkeypatch_event($e) if $mp_args;
    return;
}

#############################
# }}} Base Event Producers #
#############################

#######################
# {{{ Public helpers #
#######################

sub explain {
    my $self = shift;

    return map {
        ref $_
          ? do {
            protect { require Data::Dumper };
            my $dumper = Data::Dumper->new( [$_] );
            $dumper->Indent(1)->Terse(1);
            $dumper->Sortkeys(1) if $dumper->can("Sortkeys");
            $dumper->Dump;
          }
          : $_
    } @_;
}

sub carp {
    my $self = shift;
    $self->ctx->alert(join '' => @_);
}

sub croak {
    my $self = shift;
    $self->ctx->throw(join '' => @_);
}

sub has_plan {
    my $self = shift;

    my $plan = $self->ctx->hub->plan || return undef;
    return 'no_plan' if $plan->directive && $plan->directive eq 'NO PLAN';
    return $plan->max;
}

sub reset {
    my $self = shift;
    my %params = @_;

    $self->{use_shared} = 1 if $params{shared_hub};

    if ($self->{use_shared}) {
        Test::Stream->shared->_reset unless $params{init};
        Test::Stream->shared->state->set_legacy([]);
    }
    else {
        $self->{hub} = Test::Stream::Hub->new();
        $self->{hub}->set_use_legacy(1);
        $self->{hub}->state->set_legacy([]);
        $self->{stream} = $self->{hub}; # Test::SharedFork shim
    }

    # We leave this a global because it has to be localized and localizing
    # hash keys is just asking for pain.  Also, it was documented.
    $Level = 1;

    $self->{Name} = $0;

    $self->{Original_Pid} = $$;
    $self->{Child_Name}   = undef;

    $self->{Exported_To} = undef;

    $self->{Todo}               = undef;
    $self->{Todo_Stack}         = [];
    $self->{Start_Todo}         = 0;
    $self->{Opened_Testhandles} = 0;

    return;
}

#######################
# }}} Public helpers #
#######################

#################################
# {{{ Advanced Event Producers #
#################################

sub cmp_ok {
    my( $self, $got, $type, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->cmp_check($got, $type, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub is_eq {
    my( $self, $got, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->is_eq($got, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub is_num {
    my( $self, $got, $expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->is_num($got, $expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub isnt_eq {
    my( $self, $got, $dont_expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->isnt_eq($got, $dont_expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub isnt_num {
    my( $self, $got, $dont_expect, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->isnt_num($got, $dont_expect);
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub like {
    my( $self, $thing, $regex, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->regex_check($thing, $regex, '=~');
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

sub unlike {
    my( $self, $thing, $regex, $name ) = @_;
    my $ctx = $self->ctx;
    my ($ok, @diag) = tmt->regex_check($thing, $regex, '!~');
    $ctx->ok($ok, $name, \@diag);
    return $ok;
}

#################################
# }}} Advanced Event Producers #
#################################

################################################
# {{{ Misc #
################################################

sub _new_fh {
    my $self = shift;
    my($file_or_fh) = shift;

    return $file_or_fh if $self->is_fh($file_or_fh);

    my $fh;
    if( ref $file_or_fh eq 'SCALAR' ) {
        open $fh, ">>", $file_or_fh
          or croak("Can't open scalar ref $file_or_fh: $!");
    }
    else {
        open $fh, ">", $file_or_fh
          or croak("Can't open test output log $file_or_fh: $!");
        Test::Stream::IOSets->_autoflush($fh);
    }

    return $fh;
}

sub output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[0] = $self->_new_fh(@_) if @_;
    return $handles->[0];
}

sub failure_output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[1] = $self->_new_fh(@_) if @_;
    return $handles->[1];
}

sub todo_output {
    my $self = shift;
    my $handles = $self->ctx->hub->io_sets->init_encoding('legacy');
    $handles->[2] = $self->_new_fh(@_) if @_;
    return $handles->[2] || $handles->[0];
}

sub reset_outputs {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->io_sets->reset_legacy;
}

sub use_numbers {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_use_numbers(@_) if @_;
    $ctx->hub->use_numbers;
}

sub no_ending {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_ending(@_) if @_;
    $ctx->hub->no_ending || 0;
}

sub no_header {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_header(@_) if @_;
    $ctx->hub->no_header || 0;
}

sub no_diag {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->set_no_diag(@_) if @_;
    $ctx->hub->no_diag || 0;
}

sub exported_to {
    my($self, $pack) = @_;
    $self->{Exported_To} = $pack if defined $pack;
    return $self->{Exported_To};
}

sub is_fh {
    my $self     = shift;
    my $maybe_fh = shift;
    return 0 unless defined $maybe_fh;

    return 1 if ref $maybe_fh  eq 'GLOB';    # its a glob ref
    return 1 if ref \$maybe_fh eq 'GLOB';    # its a glob

    my $out;
    protect {
        $out = eval { $maybe_fh->isa("IO::Handle") }
            || eval { tied($maybe_fh)->can('TIEHANDLE') };
    };

    return $out;
}

sub BAILOUT { goto &BAIL_OUT }

sub expected_tests {
    my $self = shift;

    my $ctx = $self->ctx;
    $ctx->plan(@_) if @_;

    my $plan = $ctx->hub->plan || return 0;
    return $plan->max || 0;
}

sub caller {    ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    my $self = shift;

    my $ctx = $self->ctx;

    return wantarray ? $ctx->call : $ctx->package;
}

sub level {
    my( $self, $level ) = @_;
    $Level = $level if defined $level;
    return $Level;
}

sub maybe_regex {
    my ($self, $regex) = @_;
    return is_regex($regex);
}

sub is_passing {
    my $self = shift;
    my $ctx = $self->ctx;
    $ctx->hub->is_passing(@_);
}

# Yeah, this is not efficient, but it is only legacy support, barely anything
# uses it, and they really should not.
sub current_test {
    my $self = shift;

    my $ctx = $self->ctx;

    if (@_) {
        my ($num) = @_;
        my $state = $ctx->hub->state;
        $state->set_count($num);

        my $old = $state->legacy || [];
        my $new = [];

        my $nctx = $ctx->snapshot;
        $nctx->set_todo('incrementing test number');
        $nctx->set_in_todo(1);

        for (1 .. $num) {
            my $i;
            $i = shift @$old while @$old && (!$i || !$i->isa('Test::Stream::Event::Ok'));
            $i ||= Test::Stream::Event::Ok->new(
                context        => $nctx,
                created        => [CORE::caller()],
                in_subtest     => 0,
                effective_pass => 1,
            );

            push @$new => $i;
        }

        $state->set_legacy($new);
    }

    $ctx->hub->count;
}

sub details {
    my $self = shift;
    my $ctx = $self->ctx;
    my $state = $ctx->hub->state;
    my @out;
    my $legacy = $state->legacy;
    return @out unless $legacy;

    for my $e (@$legacy) {
        next unless $e && $e->isa('Test::Stream::Event::Ok');
        push @out => $e->to_legacy;
    }

    return @out;
}

sub summary {
    my $self = shift;
    my $ctx = $self->ctx;
    my $state = $ctx->hub->state;
    my $legacy = $state->legacy;
    return @{[]} unless $legacy;
    return map { $_->isa('Test::Stream::Event::Ok') ? ($_->effective_pass ? 1 : 0) : ()} @$legacy;
}

###################################
# }}} Misc #
###################################

####################
# {{{ TB1.5 stuff  #
####################

# This is just a list of method Test::Builder current does not have that Test::Builder 1.5 does.
my %TB15_METHODS = map { $_ => 1 } qw{
    _file_and_line _join_message _make_default _my_exit _reset_todo_state
    _result_to_hash _results _todo_state formatter history in_test
    no_change_exit_code post_event post_result set_formatter set_plan test_end
    test_exit_code test_start test_state
};

{
    no warnings 'redefine';
    sub AUTOLOAD {
        $Test::Builder::AUTOLOAD =~ m/^(.*)::([^:]+)$/;
        my ($package, $sub) = ($1, $2);
    
        my @caller = CORE::caller();
        my $msg    = qq{Can't locate object method "$sub" via package "$package" at $caller[1] line $caller[2].\n};
    
        $msg .= <<"        EOT" if $TB15_METHODS{$sub};

    *************************************************************************
    '$sub' is a Test::Builder 1.5 method. Test::Builder 1.5 is a dead branch.
    You need to update your code so that it no longer treats Test::Builders
    over a specific version number as anything special.

    See: http://blogs.perl.org/users/chad_exodist_granum/2014/03/testmore---new-maintainer-also-stop-version-checking.html
    *************************************************************************
        EOT
    
        die $msg;
    }
}

####################
# }}} TB1.5 stuff  #
####################

##################################
# {{{ Legacy support, do not use #
##################################

# These are here to support old versions of Test::More which may be bundled
# with some dists. See https://github.com/Test-More/test-more/issues/479

sub _try {
    my( $self, $code, %opts ) = @_;

    my $error;
    my $return;
    protect {
        $return = eval { $code->() };
        $error = $@;
    };

    die $error if $error and $opts{die_on_fail};

    return wantarray ? ( $return, $error ) : $return;
}

sub _unoverload {
    my $self = shift;
    my $type = shift;

    $self->_try(sub { require overload; }, die_on_fail => 1);

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

    return $self->_try( sub { ref $thing && $thing->isa('UNIVERSAL') } ) ? 1 : 0;
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
    return ($numval != 0 and $numval ne $val ? 1 : 0);
}

##################################
# }}} Legacy support, do not use #
##################################

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Builder - *DISCOURAGED* Module for building testing libraries.

=head1 DESCRIPTION

This module was previously the base module for almost any testing library. This
module is now little more than a compatability wrapper around L<Test::Stream>.
If you are looking to write or update a testing library you should look at
L<Test::Stream::Toolset>.

However if you must support older versions of Test-Simple/More/Builder then you
B<MUST> use this module for your testing code.

=head1 PACKAGE VARS

=over 4

=item $Test::Builder::Test

The variable that holds the Test::Builder singleton. It is best practice to
leave this variable alone, messing with it can have unexpected consequences.

=item $Test::Builder::Level

In the past this variable was used to track stack depth so that Test::Builder
could report the correct line number. If you use Test::Builder this will still
work, but in new code it is better to use the L<Test::Stream::Context> module
unless you must support older versions of Test-Simple.

=back

=head1 METHODS

=head2 CONSTRUCTORS

=over 4

=item Test::Builder->new

Returns the singleton stored in C<$Test::Builder::Test>.

=item Test::Builder->create

=item Test::Builder->create(use_shared => 1)

Returns a new instance of Test::Builder. It is important to note that this
instance will not use the shared L<Test::Stream::Hub> object unless you pass in the
C<< use_shared => 1 >> argument.

This is a way to get a new instance of Test::Builder that is not the singleton.
This is usually done for testing code.

=back

=head2 UTIL

=over 4

=item $ctx = $TB->ctx

Helper method for Test::Builder to get a L<Test::Stream::Context> object. This
is primarily for internal use, and is B<NOT> present on older versions of
Test::Builder.

=item $depth = $TB->depth

Get the subtest depth. If this is called inside a subtest the value will be 1.

=item $todo = $TB->find_TODO($package, $set, $new_value)

This is a way to find and/or set the TODO reason. This method has complex and
unintuitive logic, it is kept for legacy reasons, but it is recommended that
you not use it.

Calling with no arguments it will try to find the $TODO variable for you and
return the value.

Calling with a package will try to find the $TODO value of that package.

If you include $set and $new_value it will set the $TODO variable for the
specified package.

=item $bool = $TB->in_todo

This will return true if TODO is set, false otherwise.

=item $TB->todo()

=item $TB->todo($package)

This finds the todo message currently set, if any. If you specify a package it
will look there unless it finds a message set in the singleton.

=back

=head2 OTHER

=over 4

=item $pkg = $TB->caller

=item ($pkg, $file, $line) $TB->caller

This will try to find the details about where the test was called.

=item $TB->carp($msg)

Warn from the perspective of the test caller.

=item $TB->croak

Throw an exception from the perspective of the test caller.

=item $TB->child($name)

B<DISCOURAGED>

This used to be used internally to start a subtest. Subtests started in this
way must call C<finalize()> when they are done.

Use of this method never gained traction, and was never strictly necessary. It
has always been better to use the C<subtest()> method instead which handles the
hard work for you. This is too low level for most use cases.

=item $TB->finalize

B<DISCOURAGED>

Use this to end a subtest created via C<child()>.

=item $TB->explain(@stuff)

Interface to Data::Dumper that dumps whatever you give it. This is really just
a quick way to dump human readable test of structures.

=item $TB->exported_to

=item $TB->exported_to($package)

B<DISCOURAGED>

Test::Builder used to assume that tests would only ever be run from a single
package, usually main. This is a way to tell Test::Builder what package is
running tests. This assumption proved to be very dumb.

It is not uncommon to have tests run from many packages, as a result this
method is pretty useless if not actively harmful. Almost nothing uses this, but
it has been preserved for legacy modules.

=item $bool = $TB->is_fh($thing)

Check if something is a filehandile.

=item $num = $TB->level

=item $TB->level($num)

B<DISCOURAGED>

Get/Set C<$Test::Builder::Level>. $Level is a package var, and most things
localize it, so this method is pretty useless.

=item $bool = $TB->maybe_regex($thing)

Check if something might be a regex. These days we have C<qr//> and other
things that may make this method seem silly, however in older versions of perl
we did not have such luxuries. This method exists for old code and environments
where strings may be used as regexes.

=item $TB->reset

Reset the builder object to a very basic and default state. You almost
certainly do not need this unless you are writing a tool to test testing
libraries. Even then you probably do not want this.

In newer code using L<Test::Stream> this completely resets the state in the
shared hub as well.

=item $TB->todo_start($msg)

Set a todo message. This will make all results 'TODO' if they are generated
after this is set.

=item $TB->todo_end

Unset the TODO message.

=back

=head2 HUB INTERFACE

In older versions of Test::Builder these methods directly effected the
singleton. These days they are all compatability wrappers around
L<Test::Stream>. If possible you should use L<Test::Stream>, however if you
need to support older versions of Test::Builder these will work fine for both.

=over 4

=item $fh = $TB->failure_output

=item $fh = $TB->output

=item $fh = $TB->todo_output

=item $TB->failure_output($fh)

=item $TB->output($fh)

=item $TB->todo_output($fh)

These allow you to get and/or set the filehandle for various types of output.
Note that this will not effect UTF8 or other encodings that are specified using
the Test::Stream interface. This only effects the 'legacy' encoding used by
Test::Stream by default.

=item $TB->reset_outputs

This will reset all the outputs to the default. Note this only effects the
'legacy' encoding used by Test::Stream.

=item $TB->no_diag

Do not display L<Test::Stream::Event::Diag> events.

=item $TB->no_ending($bool)

Do not do some special magic at the end that tells you what went wrong with
tests.

=item $TB->no_header($bool)

Do not display the plan.

=item $TB->use_numbers($bool)

Turn numbers in TAP on and off.

=item $num = $TB->current_test

=back

=head2 HISTORY

=over

=item $TB->details

Get all the events that occured on this object. Each event will be transformed
into a hash that matches the legacy output of this method.

=item $TB->expected_tests

Set/Get expected number of tests

=item $TB->has_plan

Check if there is a plan

=item $TB->summary

List of pass/fail results.

=item $TB->current_test($num)

Get/Set the current test number. Setting the test number is probably not
something you want to do, except when validating testing tools.

=item $bool = $TB->is_passing

This is a way to check if the test suite is currently passing or failing.

=back

=head2 EVENT GENERATORS

See L<Test::Stream::Context>, L<Test::Stream::Toolset>, and
L<Test::More::Tools>. Calling the methods below is not advised.

=over 4

=item $TB->BAILOUT($reason)

=item $TB->BAIL_OUT($reason)

These will issue an L<Test::Stream::Event::Bail> event. This will cause the
test file to stop running immedietly with a message. In TAP this event is ALSO
a signal to the harness to abort any remaining testing.

=item $TB->cmp_ok($got, $type, $expect, $name)

    $TB->cmp_ok('foo', 'eq', 'foo', 'check that foo is foo');

Check that a comparison of C<$type> is true for the given values.

=item $TB->diag($msg)

    $TB->diag("This is a diagnostic message");

This will print a message, typically to STDERR. This message will get a '# '
prefix so that TAP harnesses see it as a comment.

=item $TB->done_testing

=item $TB->done_testing($num)

This will issue an L<Test::Stream::Event::Plan> event. This plan will set the
expected number of tests to the current test count. This will also tell
Test::Stream that the test should be done.

If you provide an argument, that argument will be used as the expected number
of tests.

=item $TB->is_eq($got, $expect, $name)

This will issue an L<Test::Stream::Event::Ok> event. If $got matches $expect
the test will pass, otherwise it will fail. This method expects values to be
strings.

=item $TB->is_num($got, $expect, $name)

This will issue an L<Test::Stream::Event::Ok> event. If $got matches $expect
the test will pass, otherwise it will fail. This method expects values to be
numerical.

=item $TB->isnt_eq($got, $dont_expect, $name)

This will issue an L<Test::Stream::Event::Ok> event. If $got matches $dont_expect
the test will fail, otherwise it will pass. This method expects values to be
strings.

=item $TB->isnt_num($got, $dont_expect, $name)

This will issue an L<Test::Stream::Event::Ok> event. If $got matches $dont_expect
the test will fail, otherwise it will pass. This method expects values to be
numerical.

=item $TB->like($thing, $regex, $name)

This will check $thing against the $regex. If it matches the test will pass.

=item $TB->unlike($thing, $regex, $name)

This will check $thing against the $regex. If it matches the test will fail.

=item $TB->no_plan

This tells Test::Builder that there should be no plan, and that is the plan.

=item $TB->note($message)

Send a message to STDOUT, it will be prefixed with '# ' so that TAP harnesses
will see it as a comment.

=item $TB->ok($bool, $name)

Issues an L<Test::Stream::Event::Ok> event. If $bool is true the test passes,
otherwise it fails.

=item $TB->plan(tests => $num)

Set the number of tests that should be run.

=item $TB->plan(skip_all => $reason)

Skip all the tests for the specified reason. $reason is a string.

=item $TB->plan('no_plan')

The plan is that there is no plan.

=item $TB->skip($reason)

Skip a single test for the specified reason. This generates a single
L<Test::Stream::Event::Ok> event.

=item $TB->skip_all($reason)

Skip all the tests for the specified reason.

=item $TB->subtest($name, sub { ... })

Run the provided codeblock as a subtest. All results will be indented, and all
that matters is the final OK.

=item $TB->todo_skip($reason)

Skip a single test with a todo message. This generates a single
L<Test::Stream::Event::Ok> event, it will have both it's 'todo' and its 'skip'
set to $reason.

=back

=head2 ACCESSORS

=over 4

=item $hub = $TB->hub

Get the hub used by this builder (or the shared hub). This is not
available on older test builders.

=item $TB->name

Name of the test builder instance, this is only useful inside a subtest.

=item $TB->parent

Parent builder instance, if this is a child.

=back

=head1 MONKEYPATCHING

Many legacy testing modules monkeypatch C<ok()>, C<plan()>, and others. The
abillity to monkeypatch these to effect all events of the specified type is now
considered discouraged. For backwords compatability monkeypatching continues to
work, however in the distant future it will be removed. L<Test::Stream> upon
which Test::Builder is now built, provides hooks and API's for doing everything
that previously required monkeypatching.

=head1 TUTORIALS

=over 4

=item L<Test::Tutorial>

The original L<Test::Tutorial>. Uses comedy to introduce you to testing from
scratch.

=item L<Test::Tutorial::WritingTests>

The L<Test::Tutorial::WritingTests> tutorial takes a more technical approach.
The idea behind this tutorial is to give you a technical introduction to
testing that can easily be used as a reference. This is for people who say
"Just tell me how to do it, and quickly!".

=item L<Test::Tutorial::WritingTools>

The L<Test::Tutorial::WritingTools> tutorial is an introduction to writing
testing tools that play nicely with other L<Test::Stream> and L<Test::Builder>
based tools. This is what you should look at if you want to write
Test::MyWidget.

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
