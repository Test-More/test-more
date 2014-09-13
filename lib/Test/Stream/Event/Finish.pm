package Test::Stream::Event::Finish;
use strict;
use warnings;

use Test::Stream::Event;
BEGIN {
    accessors qw/tests_run tests_failed/;
    Test::Stream::Event->cleanup;
};

sub to_tap { }

1;

__END__

=head1 NAME

Test::Stream::Event::Finish - The finish event type

=head1 DESCRIPTION

Sent after testing is finished.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
