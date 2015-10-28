package Test::Stream::Event::Waiting;
use strict;
use warnings;

use Test::Stream::Event;

sub global { 1 };

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Waiting - Tell all procs/threads it is time to be done

=head1 DESCRIPTION

This event has no data of its own. This event is sent out by the IPC system
when the main process/thread is ready to end.

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
