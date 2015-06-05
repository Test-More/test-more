package Test::Stream::Interceptor;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Carp qw/croak/;

use Test::Stream::Util qw/try protect/;
use Test::Stream::Context qw/context/;

use Test::Stream::Interceptor::Hub;
use Test::Stream::Interceptor::Terminator;
use Test::Stream::Interceptor::Grab;

use Test::Stream::Exporter;
exports qw/intercept lives dies warning warns no_warnings grab/;
no Test::Stream::Exporter;

sub lives(&) {
    my $code = shift;
    my ($ok, $err) = &try($code);
    return 1 if $ok;
    warn $err;
    return 0;
}

sub dies(&) {
    my $code = shift;
    my ($ok, $err) = &try($code);
    return undef if $ok;
    return $err;
}

sub warning(&) {
    my $warnings = &warns(@_) || [];
    croak "Got " . scalar(@$warnings) . " warnings, expected exactly 1"
        if @$warnings != 1;
    return $warnings->[0];
}

sub no_warnings(&) {
    my $warnings = &warns(@_);
    return 1 unless defined $warnings;
    warn $_ for @$warnings;
    return 0;
}

sub warns(&) {
    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings => @_;
    };
    &protect(@_);
    return undef unless @warnings;
    return \@warnings;
}

sub grab { Test::Stream::Interceptor::Grab->new }

sub intercept(&) {
    my $code = shift;

    my $ctx = context();

    my $ipc;
    if ($INC{'Test/Stream/IPC.pm'}) {
        my ($driver) = Test::Stream::IPC->drivers;
        $ipc = $driver->new;
    }

    my $hub = Test::Stream::Interceptor::Hub->new(
        ipc => $ipc,
        no_ending => 1,
    );

    my @events;
    $hub->listen(sub { push @events => $_[1] });

    $ctx->stack->top; # Make sure there is a top hub before we begin.
    $ctx->stack->push($hub);
    my ($ok, $err) = try {
        $code->(
            hub => $hub,
            context => $ctx->snapshot,
        );
    };
    $ctx->stack->pop($hub);

    my $dbg = $ctx->debug;
    $ctx->release;

    die $err unless $ok
        || (blessed($err) && $err->isa('Test::Stream::Interceptor::Terminator'));

    $hub->finalize($dbg)
        if $ok
        && !$hub->no_ending
        && !$hub->state->ended;

    return \@events;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Interceptor - Tools to intercept events, and other things.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    use Test::Stream::Interceptor qw{
        intercept grab lives dies warning warns no_warnings
    };

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };
    is(@$events, 2, "intercepted 2 events.");

    my $grab = grab();
        ok(1, 'foo');
        ok(0, 'bar');
    # $grab is magically undef after this.
    my $events = $grab->finish;
    is(@$events, 2, "grabbed 2 events.");

    ok(lives { ... }, "codeblock did not die");
    like(dies { die 'xxx' }, qr/xxx/, "codeblock threw expected exception");

    # Returns undef if there are no warnings.
    ok(!warns { ... }, "Codeblock did not warn");
    is_deeply(
        warns { warn "foo\n"; warn "bar\n" },
        [
            "foo\n",
            "bar\n",
        ],
        "Got expected warnings"
    );

    # Dies if there are 0 warnings, or 2+ warnings, otherwise returns the 1 warning.
    like( warning { warn 'xxx' }, qr/xxx/, "Got expected warning");

    # returns true if there are no warnings
    # return false, and prints the warnings if there are any.
    ok(no_warnings { ... }, "Did not warn.");

=head1 EXPORTS

=over 4

=item $events = intercept { ... }

This lets you intercept all events inside the codeblock. All the events will be
returned in an arrayref.

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };
    is(@$events, 2, "intercepted 2 events.");

There are also 2 named parameters passed in, C<context> and C<hub>. The
C<context> passed in is a snapshot of the context for the C<intercept()> tool
itself, referencing the parent hub. The C<hub> parameter is the new hub created
for the C<intercept> run.

    my $events = intercept {
        my %params = @_;

        my $outer_ctx = $params{context};
        my $our_hub   = $params{hub};

        ...
    };

By default the hub used has C<no_ending> set to true. This will prevent the hub
from enforcing that you issued a plan and ran at least 1 test. You can turn
enforcement back one like this:

    my %params = @_;
    $params{hub}->set_no_ending(0);

With C<no_ending> turned off, C<$hub->finalize()> will run the post-test checks
to enforce the plan and that tests were run. In many cases this will result in
additional events in your events array.

=item $grab = grab()

This lets you intercept all events for a section of code without adding
anything to your call stack. This is useful for things that are sensitive to
changes in the stack depth.

    my $grab = grab();
        ok(1, 'foo');
        ok(0, 'bar');

    # $grab is magically undef after this.
    my $events = $grab->finish;

    is(@$events, 2, "grabbed 2 events.");

When you call C<finish()> the C<$grab> object will automagically undef itself,
but only for the reference used in the method call. If you have other
references to the C<$grab> object they will not be undef'd.

If the C<$grab> object is destroyed without calling C<finish()>, it will
automatically clean up after itself and restore the parent hub.

    {
        my $grab = grab();
        # Things are grabbed
    }
    # Things are back to normal

By default the hub used has C<no_ending> set to true. This will prevent the hub
from enforcing that you issued a plan and ran at least 1 test. You can turn
enforcement back one like this:

    $grab->hub->set_no_ending(0);

With C<no_ending> turned off, C<finish> will run the post-test checks to
enforce the plan and that tests were run. In many cases this will result in
additional events in your events array.

=item $bool = lives { ... }

If the codeblock does not throw any exception this will return true. If the
codeblock does throw an exception this will return false, after printing the
exception as a warning.

    ok(lives { ... }, "codeblock did not die");

=item $error = dies { ... }

This will return undef if the codeblock does not throw an exception, otherwise
it returns the exception. Note, if your exception is an empty string or 0 it is
your responsibility to check that the error is defined instead of using a
simple boolean check.

    ok( defined dies { die 0 }, "died" );

    like(dies { die 'xxx' }, qr/xxx/, "codeblock threw expected exception");

=item $warnings = warns { ... }

If the codeblock issues any warnings they will be captured and returned in an
arrayref. If there were no warnings this will return undef. You can be sure
this will always be undef, or an arrayref with 1 or more warnings.

    # Returns undef if there are no warnings.
    ok(!warns { ... }, "Codeblock did not warn");

    is_deeply(
        warns { warn "foo\n"; warn "bar\n" },
        [
            "foo\n",
            "bar\n",
        ],
        "Got expected warnings"
    );

=item $warning = warning { ... }

Only use this for code that should issue exactly 1 warning. This will throw an
exception if there are no warnings, or if there are multiple warnings.

    like( warning { warn 'xxx' }, qr/xxx/, "Got expected warning");

These both die:

    warning { warn 'xxx'; war n'yyy' };
    warning { return };

=item $bool = no_warnings { ... }

This will return true if there are no warnings in the codeblock. This will
return false, and print the warnings if any are encountered.

    ok(no_warnings { ... }, "Did not warn.");

This is sometimes more useful that checking C<!warns { ... }> since it lets you
see the warnings when it fails.

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
