package Test::Stream::Plugin::Core;
use strict;
use warnings;

use Scalar::Util qw/reftype refaddr/;
use Carp qw/croak confess carp/;

use Test::Stream::Sync();

use Test::Stream::Table qw/table/;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw{
    protect
    get_stash
    parse_symbol
    update_mask
    render_ref
};

use Test::Stream::Exporter qw/import default_exports/;
default_exports qw{
    ok pass fail
    diag note
    plan skip_all done_testing
    BAIL_OUT
    todo skip
    can_ok isa_ok DOES_ok ref_ok
    imported_ok not_imported_ok
    ref_is ref_is_not
    set_encoding
    cmp_ok
};
no Test::Stream::Exporter;

sub set_encoding {
    my $enc = shift;
    my $format = Test::Stream::Sync->stack->top->format;

    unless ($format && eval { $format->can('encoding') }) {
        $format = '<undef>' unless defined $format;
        croak "Unable to set encoding on formatter '$format'";
    }

    $format->encoding($enc);
}

sub pass {
    my ($name) = @_;
    my $ctx = context();
    $ctx->ok(1, $name);
    $ctx->release;
    return 1;
}

sub fail {
    my ($name, @diag) = @_;
    my $ctx = context();
    $ctx->ok(0, $name, \@diag);
    $ctx->release;
    return 0;
}

sub ok($;$@) {
    my ($bool, $name, @diag) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool ? 1 : 0;
}

sub ref_is($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    $got = '<undef>' unless defined $got;
    $exp = '<undef>' unless defined $exp;

    my $bool = 0;
    if (!ref($got)) {
        $ctx->ok(0, $name, ["First argument '$got' is not a reference", @diag]);
    }
    elsif(!ref($exp)) {
        $ctx->ok(0, $name, ["Second argument '$exp' is not a reference", @diag]);
    }
    else {
        # Don't let overloading mess with us.
        $bool = refaddr($got) == refaddr($exp);
        $ctx->ok($bool, $name, ["'$got' is not the same reference as '$exp'", @diag]);
    }

    $ctx->release;
    return $bool ? 1 : 0;
}

sub ref_is_not($$;$) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    $got = '<undef>' unless defined $got;
    $exp = '<undef>' unless defined $exp;

    my $bool = 0;
    if (!ref($got)) {
        $ctx->ok(0, $name, ["First argument '$got' is not a reference", @diag]);
    }
    elsif(!ref($exp)) {
        $ctx->ok(0, $name, ["Second argument '$exp' is not a reference", @diag]);
    }
    else {
        # Don't let overloading mess with us.
        $bool = refaddr($got) != refaddr($exp);
        $ctx->ok($bool, $name, ["'$got' is the same reference as '$exp'", @diag]);
    }

    $ctx->release;
    return $bool ? 1 : 0;
}

sub diag {
    my $ctx = context();
    $ctx->diag( join '', @_ );
    $ctx->release;
}

sub note {
    my $ctx = context();
    $ctx->note( join '', @_ );
    $ctx->release;
}

sub BAIL_OUT {
    my ($reason) = @_;
    my $ctx = context();
    $ctx->bail($reason);
    $ctx->release if $ctx;
}

sub skip_all {
    my ($reason) = @_;
    my $ctx = context();
    $ctx->plan(0, SKIP => $reason);
    $ctx->release if $ctx;
}

sub plan {
    my ($max) = @_;
    my $ctx = context();
    $ctx->plan($max);
    $ctx->release;
}

update_mask('*', '*', __PACKAGE__ . '::done_testing', {lock => 1});
sub done_testing {
    my $ctx = context();
    $ctx->hub->finalize($ctx->debug, 1);
    $ctx->release;
}

sub todo {
    my $reason = shift;
    my $code   = shift;

    my $ctx = context();
    my $todo = $ctx->hub->set_todo($reason);
    $ctx->release;

    return $todo unless $code;

    # tail-end recursion to remove this stack frame from the stack trace.
    # We push $todo onto @_ so that it is not destroyed until the sub returns.
    push @_ => $todo;
    goto &$code;
}

sub skip {
    my ($why, $num) = @_;
    $num ||= 1;
    my $ctx = context();
    $ctx->skip("skipped test", $why) for 1 .. $num;
    $ctx->release;
    no warnings 'exiting';
    last SKIP;
}

# For easier grepping
# sub isa_ok  is defined here
# sub can_ok  is defined here
# sub DOES_ok is defined here
BEGIN {
    for my $op (qw/isa can DOES/) {
        my $sub = sub($;@) {
            my ($thing, @items) = @_;
            my $ctx = context();

            my $file = $ctx->debug->file;
            my $line = $ctx->debug->line;

            my @bad;
            for my $item (@items) {
                my $bool;
                protect { eval qq/#line $line "$file"\n\$bool = \$thing->$op(\$item); 1/ };
                next if $bool;

                push @bad => $item;
            }

            my $name = render_ref($thing);

            $ctx->ok(
                !@bad,
                @items == 1 ? "$name\->$op('$items[0]')" : "$name\->$op(...)",
                [map { "Failed: $name\->$op('$_')" } @bad],
            );

            $ctx->release;

            return !@bad;
        };
        no strict 'refs';
        *{$op . "_ok"} = $sub;
    }
}

sub ref_ok($;$$) {
    my ($thing, $wanttype, $name) = @_;
    my $ctx = context();

    my $gotname = render_ref($thing);
    my $gottype = reftype($thing);

    if (!$gottype) {
        $ctx->ok(0, $name, ["'$gotname' is not a reference"]);
        $ctx->release;
        return 0;
    }

    if ($wanttype && $gottype ne $wanttype) {
        $ctx->ok(0, $name, ["'$gotname' is not a '$wanttype' reference"]);
        $ctx->release;
        return 0;
    }

    $ctx->ok(1, $name);
    $ctx->release;
    return 1;
}

sub _imported {
    my $caller = shift;

    my $stash = get_stash($caller);
    my @missing;
    for my $item (@_) {
        my ($name, $type) = parse_symbol($item);

        if(my $glob = $stash->{$name}) {
            my $val = *{$glob}{$type};
            next if defined $val;
        }

        push @missing => $item;
    }

    return @missing;
}

sub imported_ok {
    my $caller = caller;

    my $ctx = context();

    my @missing = _imported($caller, @_);

    $ctx->ok(!@missing, "Imported expected symbols", [map { "'$_' was not imported." } @missing]);

    $ctx->release;

    return !@missing;
}

sub not_imported_ok {
    my $caller = caller;

    my $ctx = context();

    my %missing = map {$_ => 1} _imported($caller, @_);

    my @found = grep { !$missing{$_} } @_;

    $ctx->ok(!@found, "Did not import symbols", [map { "'$_' was imported." } @found]);

    $ctx->release;

    return !@found;
}

our %OPS = (
    '=='  => 'num',
    '!='  => 'num',
    '>='  => 'num',
    '<='  => 'num',
    '>'   => 'num',
    '<'   => 'num',
    '<=>' => 'num',

    'eq'  => 'str',
    'ne'  => 'str',
    'gt'  => 'str',
    'lt'  => 'str',
    'ge'  => 'str',
    'le'  => 'str',
    'cmp' => 'str',
    '!~'  => 'str',
    '=~'  => 'str',

    '&&'  => 'logic',
    '||'  => 'logic',
    'xor' => 'logic',
    'or'  => 'logic',
    'and' => 'logic',
    '//'  => 'logic',

    '&' => 'bitwise',
    '|' => 'bitwise',

    '~~' => 'match',
);
sub cmp_ok($$$;$@) {
    my ($got, $op, $exp, $name, @diag) = @_;

    my $ctx = context();

    # warnings and syntax errors should report to the cmp_ok call, not the test
    # context, they may not be the same.
    my ($pkg, $file, $line) = caller;

    my $type = $OPS{$op};
    if (!$type) {
        carp "operator '$op' is not supported (you can add it to %Test::Stream::Plugin::Core::OPS)";
        $type = 'unsupported';
    }

    local ($@, $!, $SIG{__DIE__});

    my $test;
    my $lived = eval <<"    EOT";
#line $line "(eval in cmp_ok) $file"
\$test = (\$got $op \$exp);
1;
    EOT
    my $error = $@;
    $ctx->send_event('Exception', error => $error) unless $lived;

    if ($test && $lived) {
        $ctx->ok(1, $name);
        $ctx->release;
        return 1;
    }

    # Uhg, it failed, do roughly the same thing Test::More did to try and show
    # diagnostics, but make it better by showing both the overloaded and
    # unoverloaded form if overloading is in play. Also unoverload numbers,
    # Test::More only unoverloaded strings.

    my ($display_got, $display_exp);
    if($type eq 'str') {
        $display_got = defined($got) ? "$got" : undef;
        $display_exp = defined($exp) ? "$exp" : undef;
    }
    elsif($type eq 'num') {
        $display_got = defined($got) ? sprintf("%D", $got) : undef;
        $display_exp = defined($exp) ? sprintf("%D", $exp) : undef;
    }
    else { # Well, we did what we could.
        $display_got = $got;
        $display_exp = $exp;
    }

    my $got_ref = ref($got) ? render_ref($got) : $got;
    my $exp_ref = ref($exp) ? render_ref($exp) : $exp;

    my @table;
    my $show_both = (
        (defined($got) && $got_ref ne "$display_got")
        ||
        (defined($exp) && $exp_ref ne "$display_exp")
    );

    if ($show_both) {
        @table = table(
            header => ['type', 'got', 'op', 'check'],
            rows   => [
                [$type, $display_got, $op, $lived ? $display_exp : '<EXCEPTION>'],
                ['orig', $got_ref, '', $exp_ref],
            ],
        );
    }
    else {
        @table = table(
            header => ['got', 'op', 'check'],
            rows   => [[$display_got, $op, $lived ? $display_exp : '<EXCEPTION>']],
        );
    }

    $ctx->ok(0, $name, [@table, @diag]);
    $ctx->release;
    return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Core - Test::Stream implementation of the core testing
tools.

=head1 DESCRIPTION

B<This is not a drop-in replacement for Test::More>.

The new Testing library to replace L<Test::More>. This library is directly
built on new internals instead of L<Test::Builder>.

This module implements I<most> of the same functionality as L<Test::More>, but
since changing to this library from L<Test::More> is not automatic, some
incompatible API changes have been made. If you decide to replace L<Test::More>
in existing test files, you may have to update some function calls.

=head1 SYNOPSIS

    use Test::Stream qw/Core/;

    set_encoding('utf8');

    plan($num); # Optional, set a plan

    use Data::Dumper;
    imported_ok qw/Dumper/;
    not_imported_ok qw/dumper/;

    # skip all tests in some condition
    skip_all("do not run") if $cond;

    if ($passing) {
        pass('a passing test');
    }
    else {
        fail('a failing test');
    }

    ok($x, "simple test");

    # Check that the class or object has the specified methods defined.
    can_ok($class_or_obj, @methods);

    # Check that the class or object is or subclasses the specified packages
    isa_ok($class_or_obj, @packages);

    # Check that the class or object consumes the specified roles.
    DOES_ok($class_or_obj, @roles);

    # Check that $ref is a HASH reference
    ref_ok($ref, 'HASH', 'Must be a hash')

    # The preferred way to plan
    done_testing;

=head1 EXPORTS

All subs are exported by default.

=head2 ASSERTIONS

=over 4

=item ok($bool)

=item ok($bool, $name)

=item ok($bool, $name, @diag)

Simple assertion. If C<$bool> is true the test passes, if it is false the test
fails. The test name is optional, and all arguments after the name are added as
diagnostics message if and only if the test fails. If the test passes all the
diagnostics arguments will be ignored.

=item pass()

=item pass($name)

Fire off a passing test (a single Ok event). The name is optional

=item fail()

=item fail($name)

=item fail($name, @diag)

Fire off a failing test (a single Ok event). The name and diagnostics are optional.

=item imported_ok(@SUB_NAMES)

Check that the specified subs have been defined in the current namespace. This
will NOT find inherited subs, the subs must be in the current namespace.

=item not_imported_ok(@SUB_NAMES)

Check that the specified subs have NOT been defined in the current namespace.
This will NOT find inherited subs, the subs must be in the current namespace.

=item can_ok($thing, @methods)

This checks that C<$thing> (either a class name, or a blessed instance) has the
specified methods.

=item isa_ok($thing, @classes)

This checks that C<$thing> (either a class name, or a blessed instance) is or
subclasses the specified classes.

=item DOES_ok($thing, @roles)

This checks that C<$thing> (either a class name, or a blessed instance) does
the specified roles.

=item ref_ok($thing)

=item ref_ok($thing, $type)

=item ref_ok($thing, $type, $name)

This checks that C<$thing> is a reference. If C<$type> is specified then it
will check that C<$thing> is that type of reference.

=item ref_is($ref1, $ref2, $name)

Verify that 2 references are the exact same reference.

=item ref_is_not($ref1, $ref2, $name)

Verify that 2 references are not the exact same reference.

=item cmp_ok($got, $op, $expect)

=item cmp_ok($got, $op, $expect, $name)

=item cmp_ok($got, $op, $expect, $name, @diag)

Compare C<$got> to C<$expect> using the operator specified in C<$op>. This is
effectively a C<eval "\$got $op \$expect"> with some other stuff to make it
more sane. This is useful for comparing numbers, overloaded objects, etc.

B<Overloading Note:> Your input is passed as-is to the comparison. In the event
that the comparison fails between 2 overloaded objects, the diagnostics will
try to show you the overload form that was used in comparisons. It is possible
that the diagnostics will be wrong, though attempts have been made to improve
them since L<Test::More>.

B<Exceptions:> If the comparison results in an exception then the test will
fail and the exception will be shown.

cmp_ok has an internal list of operators it supports. If you provide an
unsupported operator it will issue a warning. You can add operators to the
C<%Test::Stream::Plugin::Core::OPS> hash, the key should be the operator, and
the value should either be 'str' for string comparison operators, 'num' for
numeric operators, or any other true value for other operators.

Supported operators:

=over 4

=item ==  (num)

=item !=  (num)

=item >=  (num)

=item <=  (num)

=item >   (num)

=item <   (num)

=item <=> (num)

=item eq  (str)

=item ne  (str)

=item gt  (str)

=item lt  (str)

=item ge  (str)

=item le  (str)

=item cmp (str)

=item !~  (str)

=item =~  (str)

=item &&

=item ||

=item xor

=item or

=item and

=item //

=item &

=item |

=item ~~

=back

=back

=head2 DIAGNOSTICS

=over 4

=item diag(@messages)

Write diagnostics messages. All items in C<@messages> will be joined into a
single string with no seperator. When using TAP diagnostics are sent to STDERR.

=item note(@messages)

Write note-diagnostics messages. All items in C<@messages> will be joined into
a single string with no seperator. When using TAP note-diagnostics are sent to
STDOUT.

=back

=head2 PLANNING

=over 4

=item plan($num)

Set the number of tests that are expected. This must be done first or last,
never in the middle of testing.

=item skip_all($reason)

Set the plan to 0 with a reason, then exit true. This should be used before any
tests are run.

=item done_testing

Used to mark the end of testing. This is a safe way to have a dynamic or
unknown number of tests.

=item BAIL_OUT($reason)

Something has gone horribly wrong, stop everything, kill all threads and
processes, end the process with a false exit status.

=back

=head2 META

=over 4

=item $todo = todo($reason)

=item todo $reason => sub { ... }

This is used to mark some results as TODO. TODO means that the test may fail,
but will not cause the overall test suite to fail.

There are 2 ways to use this, the first is to use a codeblock, the TODO will
only apply to the codeblock.

    ok(1, "before"); # Not TODO

    todo 'this will fail' => sub {
        # This is TODO, as is any other test in this block.
        ok(0, "blah");
    };

    ok(1, "after"); # Not TODO

The other way is to use a scoped variable, TODO will end when the variable is
destroyed or set to undef.

    ok(1, "before"); # Not TODO

    {
        my $todo = todo 'this will fail';

        # This is TODO, as is any other test in this block.
        ok(0, "blah");
    };

    ok(1, "after"); # Not TODO

This is the same thing, but without the C<{...}> scope.

    ok(1, "before"); # Not TODO

    my $todo = todo 'this will fail';

    ok(0, "blah"); # TODO

    $todo = undef;

    ok(1, "after"); # Not TODO

=item skip($why)

=item skip($why, $count)

This is used to skip some tests. This requires you to wrap your tests in a
block labeled C<SKIP:>, this is somewhat magical. If no C<$count> is specified
then it will issue a single result. If you specify C<$count> it will issue that
many results.

    SKIP: {
        skip "This will wipe your drive";

        # This never gets run:
        ok(!system('sudo rm -rf /'), "Wipe drive");
    }

=item set_encoding($encoding)

This will set the encoding to whatever you specify. This will only effect the
output of the current formatter, which is usually your TAP output formatter.

=back

=head1 SEE ALSO

=over 4

=item L<Test::Stream::Plugin::Subtest>

Subtest support

=item L<Test::Stream::Plugin::Intercept>

Tools for intercepting events, exceptions, warnings, etc.

=item L<Test::Stream::Bundle::Tester>

Tools for testing your test tools

=item L<Test::Stream::Plugin::IPC>

Use this module directly for more control over concurrency.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
