package Test::Builder::Event::Note;
use strict;
use warnings;

use base 'Test::Builder::Event';

use Carp qw/confess/;

sub init {
    my ($self, $context, $message) = @_;
    $self->{message} = $message || confess "No message set for note!";
}

sub to_tap {
    my $self = shift;

    chomp(my $msg = $self->message);
    $msg = "# $msg" unless $msg =~ m/^\n/;
    $msg =~ s/\n/\n# /g;
    return "$msg\n";
}

1;

__END__

=head1 NAME

Test::Builder::Event::Note - Note event type

=head1 DESCRIPTION

Notes in tests

=head1 METHODS

See L<Test::Builder::Event> which is the base class for this module.

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

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
