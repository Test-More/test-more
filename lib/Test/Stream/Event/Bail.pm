package Test::Stream::Event::Bail;
use strict;
use warnings;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event;
BEGIN {
    accessors qw/reason quiet/;
    Test::Stream::Event->cleanup;
};

sub to_tap {
    my $self = shift;
    return if $self->[QUIET];
    return (
        OUT_STD,
        "Bail out!  " . $self->reason . "\n",
    );
}

1;

__END__

=head1 NAME

Test::Stream::Event::Bail - Bailout!

=head1 DESCRIPTION

Sent when the test needs to bail out.

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
