package Test::Builder::Event::Diag;
use strict;
use warnings;

use base 'Test::Builder::Event';

use Test::Builder::Util qw/try/;
use Encode();
use Carp qw/confess/;

my $NORMALIZE = try { require Unicode::Normalize; 1 };

sub message { $_[0]->{message} }

sub init {
    my ($self, $context, $message) = @_;
    $self->{message} = $message || confess "No message set for diag!";
}

sub to_tap {
    my $self = shift;

    chomp(my $msg = $self->message);

    my $encoding = $self->context->encoding;
    if ($encoding ne 'legacy') {
        my $file = $self->context->file;
        my $decoded;
        try { $decoded = Encode::decode($encoding, "$file", Encode::FB_CROAK) };
        if ($decoded) {
            $decoded = Unicode::Normalize::NFKC($decoded) if $NORMALIZE;
            $msg =~ s/$file/$decoded/g;
        }
    }

    $msg = "# $msg" unless $msg =~ m/^\n/;
    $msg =~ s/\n/\n# /g;
    return "$msg\n";
}

1;

__END__

=head1 NAME

Test::Builder::Event::Diag - Diag event type

=head1 DESCRIPTION

The diag event type.

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
