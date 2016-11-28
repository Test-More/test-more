package Test2::Util::Table::LineBreak;
use strict;
use warnings;

our $VERSION = '0.000062';

use Carp qw/croak/;
use Scalar::Util qw/blessed/;
use Test2::Util::Term qw/uni_length/;

use Test2::Util::HashBase qw/string gcstring _len _parts idx/;

sub init {
    my $self = shift;

    croak "string is a required attribute"
        unless defined $self->{+STRING};
}

sub columns { uni_length($_[0]->{+STRING}) }

sub break {
    my $self = shift;
    my ($len) = @_;
    $self->{+_LEN} = $len;

    $self->{+IDX} = 0;
    my $str = $self->{+STRING} . ""; # Force stringification

    binmode(STDOUT, ':utf8');
    my @parts;
    my @chars = split //, $str;
    while (@chars) {
        my $size = 0;
        my $part = '';
        until ($size == $len) {
            my $char = shift @chars;
            $char = '' unless defined $char;

            my $l = uni_length("$char");
            last unless $l;

            if ($char eq "\n") {
                last;
                next;
            }

            if ($size + $l > $len) {
                unshift @chars => $char;
                last;
            }

            $size += $l;
            $part .= $char;
        }
        until ($size == $len) {
            $part .= ' ';
            $size += 1;
        }
        push @parts => $part;
    }

    $self->{+_PARTS} = \@parts;
}

sub next {
    my $self = shift;

    if (@_) {
        my ($len) = @_;
        $self->break($len) if !$self->{+_LEN} || $self->{+_LEN} != $len;
    }
    else {
        croak "String has not yet been broken"
            unless $self->{+_PARTS};
    }

    my $idx   = $self->{+IDX}++;
    my $parts = $self->{+_PARTS};

    return undef if $idx >= @$parts;
    return $parts->[$idx];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Util::Table::LineBreak - Break up lines for use in tables.

=head1 DESCRIPTION

This is meant for internal use. This package takes long lines of text and
splits them so that they fit in table rows.

=head1 SYNOPSIS

    use Test2::Util::Table::LineBreak;

    my $lb = Test2::Util::Table::LineBreak->new(string => $STRING);

    $lb->break($SIZE);
    while (my $part = $lb->next) {
        ...
    }

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<http://github.com/Test-More/Test2-Suite/>.

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
