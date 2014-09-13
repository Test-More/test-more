package Test::Stream::Event::Diag;
use strict;
use warnings;

use Test::Stream qw/OUT_ERR OUT_TODO/;
use Test::Stream::Event;
BEGIN {
    accessors qw/message linked/;
    Test::Stream::Event->cleanup;
};

use Encode();
use Test::Stream::Util qw/try/;
use Scalar::Util qw/weaken/;
use Test::Stream::Carp qw/confess/;

my $NORMALIZE = try { require Unicode::Normalize; 1 };

sub init {
    $_[0]->[MESSAGE] ||= 'undef';
    weaken($_[0]->[LINKED]) if $_[0]->[LINKED];
}

sub link {
    my $self = shift;
    my ($to) = @_;
    confess "Already linked!" if $self->[LINKED];
    $self->[LINKED] = $to;
    weaken($self->[LINKED]);
}

sub to_tap {
    my $self = shift;

    chomp(my $msg = $self->[MESSAGE]);

    my $encoding = $self->[CONTEXT]->encoding;
    if ($encoding ne 'legacy') {
        my $file = $self->[CONTEXT]->file;
        my $decoded;
        try { $decoded = Encode::decode($encoding, "$file", Encode::FB_CROAK) };
        if ($decoded) {
            $decoded = Unicode::Normalize::NFKC($decoded) if $NORMALIZE;
            $msg =~ s/$file/$decoded/g;
        }
    }

    $msg = "# $msg" unless $msg =~ m/^\n/;
    $msg =~ s/\n/\n# /g;

    return (
        ($self->[CONTEXT]->diag_todo ? OUT_TODO : OUT_ERR),
        "$msg\n",
    );
}

1;

__END__

=head1 NAME

Test::Stream::Event::Diag - Diag event type

=head1 DESCRIPTION

The diag event type.

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
