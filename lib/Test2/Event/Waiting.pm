package Test2::Event::Waiting;
use strict;
use warnings;

use base 'Test2::Event';

sub global { 1 };

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Waiting - Tell all procs/threads it is time to be done

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

This event has no data of its own. This event is sent out by the IPC system
when the main process/thread is ready to end.

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
