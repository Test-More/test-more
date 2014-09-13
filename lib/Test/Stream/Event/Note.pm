package Test::Stream::Event::Note;
use strict;
use warnings;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event;
BEGIN {
    accessors qw/message/;
    Test::Stream::Event->cleanup;
};

use Test::Stream::Carp qw/confess/;

sub init {
    confess "No message set for note!" unless $_[0]->[MESSAGE];
}

sub to_tap {
    my $self = shift;

    chomp(my $msg = $self->[MESSAGE]);
    $msg = "# $msg" unless $msg =~ m/^\n/;
    $msg =~ s/\n/\n# /g;

    return (OUT_STD, "$msg\n");
}

1;

__END__

=head1 NAME

Test::Stream::Event::Note - Note event type

=head1 DESCRIPTION

Notes in tests

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

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
