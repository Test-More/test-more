package Test::Stream::Plugin::Intercept;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

use Test::Stream::Util qw/try/;
use Test::Stream::Context qw/context/;

use Test::Stream::Hub::Interceptor;
use Test::Stream::Hub::Interceptor::Terminator;

use Test::Stream::Exporter;
default_exports qw/intercept/;
no Test::Stream::Exporter;

sub intercept(&) {
    my $code = shift;

    my $ctx = context();

    my $ipc;
    if ($INC{'Test/Stream/IPC.pm'}) {
        my ($driver) = Test::Stream::IPC->drivers;
        $ipc = $driver->new;
    }

    my $hub = Test::Stream::Hub::Interceptor->new(
        ipc => $ipc,
        no_ending => 1,
    );

    my @events;
    $hub->listen(sub { push @events => $_[1] });

    $ctx->stack->top; # Make sure there is a top hub before we begin.
    $ctx->stack->push($hub);
    my ($ok, $err) = try {
        local $ENV{TS_TERM_SIZE} = 80;
        $code->(
            hub => $hub,
            context => $ctx->snapshot,
        );
    };
    $hub->cull;
    $ctx->stack->pop($hub);

    my $dbg = $ctx->debug;
    $ctx->release;

    die $err unless $ok
        || (blessed($err) && $err->isa('Test::Stream::Hub::Interceptor::Terminator'));

    $hub->finalize($dbg, 1)
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

Test::Stream::Plugin::Intercept - Tool for intercepting test events.

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

    # Load the Intercept plugin, and More since we need that one as well.
    use Test::Stream qw/Intercept More/;

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };

    is(@$events, 2, "intercepted 2 events.");

    isa_ok($events->[0], 'Test::Stream::Event::Ok');
    ok($events->[0]->pass, "first event passed");

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

B<Note:> the C<$ENV{TS_TERM_SIZE}> environment variable is set to 80 inside the
intercept block. This is done to ensure consistency for the block across
machines and platforms. This is essential for predictable testing of
diagnostics, which may render tables or use the terminal size to change
behavior.

=back

=head1 SEE ALSO

L<Test::Stream::Plugin::Grab> - Similar tool, but allows you to intercept
events without adding stack frames.

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
