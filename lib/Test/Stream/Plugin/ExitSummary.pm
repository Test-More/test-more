package Test::Stream::Plugin::ExitSummary;
use strict;
use warnings;

use Test::Stream::Plugin;

my $ADDED_HOOK = 0;
sub load_ts_plugin {
    require Test::Stream::Sync;
    Test::Stream::Sync->add_hook(\&summary) unless $ADDED_HOOK++;
}

sub summary {
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

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::ExitSummary - Add extra diagnostics on failure at the end of the
test.

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

This will provide some diagnostics after a failed test. These diagnostics can
range from telling you how you deviated from your plan, warning you if there
was no plan, etc. People used to L<Test::More> generally expect these
diagnostics.

=head1 SYNOPSIS

    use Test::Stream qw/ExitSummary .../;

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
