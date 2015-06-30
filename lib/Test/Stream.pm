package Test::Stream;
use strict;
use warnings;
use vars qw/$VERSION/;

$Test::Stream::VERSION = '1.302008';
$VERSION = eval $VERSION;

use Scalar::Util qw/reftype/;
use Carp qw/croak/;

use Test::Stream::IPC;

use Test::Stream::Sync;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/try/;

use Test::Stream::DeepCheck(
    qw/check/,
    strict_compare  => { -as => 'is_deeply'   },
    relaxed_compare => { -as => 'mostly_like' },
);

use Test::Stream::Exporter qw/default_exports exports export_to/;
exports qw/context/;
default_exports qw{
    ok pass fail
    is isnt
    like unlike
    cmp_ok
    is_deeply
    mostly_like
    diag note
    plan skip_all done_testing
    BAIL_OUT
    todo skip
    can_ok isa_ok does_ok ref_ok
};
no Test::Stream::Exporter;

my $ADDED_HOOK = 0;

sub import {
    my $class  = shift;
    my $caller = caller;

    strict->import();
    warnings->import();

    Test::Stream::Sync->add_hook(
        sub {
            my ($ctx, $real, $new) = @_;

            my $state  = $ctx->hub->state;
            my $plan   = $state->plan;
            my $count  = $state->count;
            my $failed = $state->failed;

            $ctx->diag('No tests run!') if !$count && (!$plan || $plan ne 'SKIP');
            $ctx->diag('Tests were run but no plan was declared and done_testing() was not seen.')
                if $count && !$plan;

            $ctx->diag("Looks like your test exited with $real after test #$count.")
                if $real;

            $ctx->diag("Did not follow plan: expected $plan, ran $count.")
                if $plan && $plan =~ m/^\d+$/ && defined $count && $count != $plan;
        }
    ) unless $ADDED_HOOK++;

    $class->export_to($caller, \@_);
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

sub is($$;$@) {
    my ($got, $want, $name, @diag) = @_;
    my $ctx = context();

    my $check = check('eq', $want);
    my $bool = $check->verify($got);

    unshift @diag => "Failed check: " . $check->diag($got)
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;

    return $bool ? 1 : 0;
}

sub isnt($$;$@) {
    my ($got, $want, $name, @diag) = @_;
    my $ctx = context();

    my $check = check('ne', $want);
    my $bool = $check->verify($got);

    unshift @diag => "Failed check: " . $check->diag($got)
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
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

sub like($$;$@) {
    my ($got, $pattern, $name, @diag) = @_;
    my $ctx = context();

    my $check = check('=~', $pattern);
    my $bool = $check->verify($got);

    unshift @diag => "Failed check: " . $check->diag($got)
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;

    return $bool ? 1 : 0;
}

sub unlike($$;$@) {
    my ($got, $pattern, $name, @diag) = @_;
    my $ctx = context();

    my $check = check('!~', $pattern);
    my $bool = $check->verify($got);

    unshift @diag => "Failed check: " . $check->diag($got)
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;

    return $bool ? 1 : 0;
}

sub cmp_ok($$$;$@) {
    my ($got, $cmp, $want, $name, @diag) = @_;
    my $ctx = context();

    my $check = check($cmp, $want);
    my $bool = $check->verify($got);

    unshift @diag => "Failed check: " . $check->diag($got)
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;

    return $bool ? 1 : 0;
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

sub done_testing {
    my $ctx = context();
    my $state = $ctx->hub->state;

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
    $ctx->debug->set_skip($why);
    $ctx->ok(1, "skipped test") for 1 .. $num;
    $ctx->debug->set_skip(undef);
    $ctx->release;
    no warnings 'exiting';
    last SKIP;
}

BEGIN {
    for my $op (qw/isa can does/) {
        my $sub = sub($;@) {
            my ($thing, @items) = @_;
            my $ctx = context();

            my @bad;
            for my $item (@items) {
                my $bool;
                my $line = __LINE__ + 1;
                my ($ok, $err) = try { $bool = $thing->$op($item) };
                next if $bool;

                if ($err) {
                    my $file = __FILE__;
                    chomp($err);
                    $err =~ s/ at \Q$file\E line $line.*$//;
                    $ctx->debug->throw($err);
                }

                push @bad => $item;
            }

            $ctx->ok(
                !@bad,
                @items == 1 ? "$thing\->$op('$items[0]')" : "$thing\->$op(...)",
                [map { "Failed: $thing\->$op('$_')" } @bad],
            );

            $ctx->release;

            return !@bad;
        };
        no strict 'refs';
        *{"${op}_ok"} = $sub;
    }
}

sub ref_ok($;$$) {
    my ($thing, $wanttype, $name) = @_;
    my $ctx = context();

    my $gottype = reftype($thing);

    if (!$gottype) {
        $ctx->ok(0, $name, ["'$thing' is not a reference"]);
        $ctx->release;
        return 0;
    }

    if ($wanttype && $gottype ne $wanttype) {
        $ctx->ok(0, $name, ["'$thing' is not a '$wanttype' reference"]);
        $ctx->release;
        return 0;
    }

    $ctx->ok(1, $name);
    $ctx->release;
    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream - Experimental successor to Test::More and Test::Builder.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

B<This is not a drop-in replacement for Test::More>.

The new Testing library to replace L<Test::More>. This library is directly
built on new internals instead of L<Test::Builder>.

This module implements I<most> of the same functionality as L<Test::More>, but
since changing to this library from L<Test::More> is not automatic, some
incompatible API changes have been made. If you decide to replace L<Test::More>
in existing test files, you may have to update some function calls.

=head1 SYNOPSIS

    use Test::Stream;

    plan($num); # Optional, set a plan

    # skip all tests in some condition
    skip_all("do not run") if $cond;

    if ($passing) {
        pass('a passing test');
    }
    else {
        fail('a failing test');
    }

    ok($x, "simple test");

    is($a, $b, "'eq' test");

    isnt($a, $b, "'ne' test");

    like($x, qr/xxx/, "Check that $x matches the regex");

    unlike($x, qr/xxx/, "Check that $x does not match the regex");

    cmp_ok($a, '==', $b, "Comparison of the specified type");

    is_deeply($a, ..., "deep structure test");

    mostly_like($a, ..., "Less strict, more helpful structure test");

    # Check that the class or object has the specified methods defined.
    can_ok($class_or_obj, @methods);

    # Check that the class or object is or subclasses the specified packages
    isa_ok($class_or_obj, @packages);

    # Check that the class or object consumes the specified roles.
    does_ok($class_or_obj, @roles);

    # Check that $ref is a HASH reference
    ref_ok($ref, 'HASH', 'Must be a hash')

    # The preferred way to plan
    done_testing;

=head1 IPC NOTE

L<Test::Stream::IPC> is loaded by default, as such forking and threading should
work fine so long as you did not fork or start your threads before loading
Test::Stream.

B<However!> polling is not turned on by default as it can result in significant
slowdowns on purely serial code. This means that results from child processes
and threads will not usually be seen until the main process/thread is complete.
If you want to see results as they happen you need to turn on polling.

This will turn on polling:

    use Test::Stream::IPC 'polling';

An alternative would be to use the C<cull()> function also provided by
L<Test::Stream::IPC> to manually cull results where you want them:

    use Test::Stream::IPC 'cull';
    ...
    cull()
    ...

=head1 EXPORTS

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

=item is($a, $b)

=item is($a, $b, $name)

=item is($a, $b, $name, @diag)

This does a comparison of C<$a> and C<$b> using the C<eq> operator. This is
usually what you want, but can be the wrong choice when comparing numbers that
may be equal, but represented differently, ie C<'1.0' eq '1'> will fail.

Name and diag are optional. Diag is only used if the test fails.

=item isnt($a, $b)

=item isnt($a, $b, $name)

=item isnt($a, $b, $name, @diag)

Same as C<is()> except the C<ne> operator is used.

=item like($string, $pattern)

=item like($string, $pattern, $name)

=item like($string, $pattern, $name, @diag)

Check that C<$string> matches C<$pattern> using the C<=~> operator.

Name and diag are optional. Diag is only used if the test fails.

=item unlike($string, $pattern)

=item unlike($string, $pattern, $name)

=item unlike($string, $pattern, $name, @diag)

Same as C<like()> except that the check is that the string does not match the
pattern. The C<!~> operator is used instead of the C<=~> operator.

=item cmp_ok($a, $op, $b)

=item cmp_ok($a, $op, $b, $name)

=item cmp_ok($a, $op, $b, $name, @diag)

Compare 2 variables using the specified comparison operator. Name and diag are
optional, diag is only used if the check fails.

=item is_deeply($a, $b)

=item is_deeply($a, $b, $name)

Do a deep comparison between C<$a> and C<$b>. All hashrefs and arrayrefs are
checked element by element. If an element is in one but not the other it will
fail. If there is any difference at all the test fails.

This attempts ot be smart about numbers vs string vs references when doing
comparions, so it uses C<eq> most times, but C<==> if both sides look like
numbers, or if both sides are references other than hash/array.

=item mostly_like($a, $b)

=item mostly_like($a, $b, $name)

This is much like C<is_deeply> except that it is more friendly. This will
ignore hash elements in C<$a> that are not listed in C<$b>. If you put a regex
into C<$b> then the same item in C<$a> will be verified against that regex. If
you put a coderef in C<$b> it will be called with the value recieved and its
return value will determine if it is a match or not.

    # This passes, 'xxx' is checked against the regex
    mostly_like(
        { a => 'xxx' },
        { a => qr/xxx/ }
    );

    # This passes, the coderef is run
    mostly_like(
        { a => 'xxx' }.
        { a => sub { $_[0] eq 'xxx' } }
    );

    # This passes, the extra fields are ignored
    mostly_like(
        { a => 'xxx', _private => 'stuff' },
        { a => 'xxx' },
    );

    # This does B<NOT> pass, extra array elements are a problem
    mostly_like(
        [ qw/a b c d/ ],
        [ qw/a b c/   ]
    );

=item can_ok($thing, @methods)

This checks that C<$thing> (either a class name, or a blessed instance) has the
specified methods.

=item isa_ok($thing, @classes)

This checks that C<$thing> (either a class name, or a blessed instance) is or
subclasses the specified classes.

=item does_ok($thing, @roles)

This checks that C<$thing> (either a class name, or a blessed instance) does
the specified roles.

=item ref_ok($thing)

=item ref_ok($thing, $type)

=item ref_ok($thing, $type, $name)

This checks that C<$thing> is a reference. If C<$type> is specified then it
will check that C<$thing> is that type of reference.

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

=back

=head1 NOTABLE DIFFERENCES FROM Test::More

=over 4

=item API Change: 'strict' and 'warnings' are enabled for you

No more need to type:

    use strict;
    use warnings;

Using Test::Stream does it for you:

    use Test::Stream;

=item API Change: Cannot set plan at import

C<done_testing> is the preferred way to plan. However if you really want a plan
you can use the C<plan()> or C<skip_all> functions. Setting the plan at compile
time resulted in bugs in the past (primarily with subtests that loaded external
files), moving away from that API shortcut helps to make things cleaner.

=item API Change: isa_ok($thing, @classes)

C<isa_ok> used to take a thing, a class, and an alternate name for thing. It
tried to be overly clever and broke from expectations set by C<can_ok>.

Also changed such that you cannot use this to check the reftype of C<$thing>.
See C<ref_ok()> for checking item reftypes.

=item API Change: done_testing() does not take args

Most people were unaware, but C<done_testing()> in L<Test::More> could take the
number of expected tests as an argument. This feature was rarely used, and
suprisingly complicated to implement.

=item API Change: plan() arguments

C<plan()> now only takes the expected number of tests. If you want to skip all
the tests use C<skip_all()>. There is no way to set C<'no plan'>, use
C<done_testing()> instead.

=item API Change: subtest is in a different library

Look at L<Test::Stream::Subtest> if you want to use subtests.

=item API Change: no $TODO variable

=item API Added: $todo = todo($reason)

C<$TODO> is not imported, and will be ignored. Instead use
C<my $todo = todo($reason)>. This will work similarly to the old api where
C<$TODO> was localized in that the todo goes away when $todo is unset or
destroyed.

    {
        my $todo = todo('foo');
        ok(0, "this is todo");
    }
    ok(1, "this is not todo");

Or:

    my $todo = todo('foo');
    ok(0, "this is todo");
    $todo = undef; # Unset todo.
    ok(1, "this is not todo");

=item API Added: does_ok($class, @roles)

Same as C<isa_ok> and C<can_ok> except that it calls C<< $thing->does(...) >>
instead of C<< $thing->can(...) >> or C<< $thing->isa(...) >>.

=item API Added: skip_all

There is now a C<skip_all()> function that can be used to skip all tests.

=item API Removed: use_ok($class, @args)

=item API Removed: require_ok($class, $version)

Errors loading modules cause the test to die anyway, so just load them, if they
do not work the test will fail. Making a seperate API for this is a wasted
effort. Also doing this requires the functions to guess if you provided a
module name, or filename, and then munging the input to figure out what
actually needs to be loaded.

=item API Removed: new_ok($class, \@args, $name)

This is easy enough:

    ok(my $one = $class->new(@args), "NAME");

The utility of c<new_ok()> is questionable at best.

=item API Removed: eq_array eq_hash eq_set

L<Test::More> itself discourages you from using these, so we are not carrying
them forward.

=item API Removed: explain

This method was copied in an API-incompatible way from L<Test::Most>. This
created an incompatability issue between the 2 libraries and made a real mess
of things. There is value in a tool like this, but if it is added it will be
added with a new name to avoid conflicts.

=back

=head1 SEE ALSO

=over 4

=item L<Test::Stream::Subtest>

Subtest support

=item L<Test::Stream::Intercept>

Tools for intercepting events, exceptions, warnings, etc.

=item L<Test::Stream::Tester>

Tools for testing your test tools

=item L<Test::Stream::IPC>

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
