package Test2::Event::Waiting;
use strict;
use warnings;

our $VERSION = '1.302078';

BEGIN { require Test2::Event; our @ISA = qw(Test2::Event) }
use Test2::Util::HashBase;

sub terminate ()        { }
sub sets_plan ()        { }
sub global ()           { 1 }
sub no_debug ()         { 1 }
sub no_legacy_facets () { 1 }
sub gravity ()          { 0 }
sub increments_count () { 0 }
sub no_display ()       { 0 }
sub diagnostics ()      { 0 }
sub causes_fail ()      { 0 }

sub summary { "IPC is waiting for children to finish..." }

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{+NO_LEGACY_FACETS} = 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Waiting - Tell all procs/threads it is time to be done

=head1 DESCRIPTION

This event has no data of its own. This event is sent out by the IPC system
when the main process/thread is ready to end.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
