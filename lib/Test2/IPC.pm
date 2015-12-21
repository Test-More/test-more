package Test2::IPC;
use strict;
use warnings;

use Test2::Global();

our @EXPORT_OK = qw/cull/;
use base 'Exporter';

die __PACKAGE__ . " was loaded too late, IPC will not be enabled!"
    if Test2::Global::test2_init_done() && !Test2::Global::test2_ipc();

sub cull {
    my $ctx = context();
    $ctx->hub->cull;
    $ctx->release;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::IPC - Turn on IPC for threading or forking support.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 SYNOPSIS

You should C<use Test2::IPC;> as early as possible in your test file.
L<Test2::IPC> cannot be loaded after the first context is obtained.

    use Test2::IPC;
    # IPC is now enabled.

=head1 EXPORTS

All exports are optional.

=over 4

=item cull()

Cull allows you to collect results from other processes or threads on demand.

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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
