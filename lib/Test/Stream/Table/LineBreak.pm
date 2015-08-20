package Test::Stream::Table::LineBreak;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/blessed/;

# Optional.
eval { require Unicode::GCString; 1 };

use Test::Stream::HashBase(
    accessors => [qw/string gcstring lbreak _parts idx/],
);

sub init {
    my $self = shift;

    croak "string is a required attribute"
        unless defined $self->{+STRING};

    return unless $INC{'Unicode/GCString.pm'};
    $self->{+GCSTRING} = Unicode::GCString->new($self->{+STRING});
}

sub columns {
    my $self = shift;
    return $self->{+GCSTRING}->columns if $self->{+GCSTRING};
    return length($self->{+STRING});
}

sub break {
    my $self = shift;
    my ($len) = @_;

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
            my $l = $INC{'Unicode/GCString.pm'} ? Unicode::GCString->new("$char")->columns : length($char);
            last unless $l;
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

    croak "String has not yet been broken"
        unless $self->{+_PARTS};

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

Test::Stream::Table::LineBreak - Break up lines for use in tables.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This is meant for internal use. This package takes long lines of text and
splits them so that they fit in table rows.

=head1 SYNOPSIS

    use Test::Stream::Table::LineBreak;

    my $lb = Test::Stream::Table::LineBreak->new(string => $STRING);

    $lb->break($SIZE);
    while (my $part = $lb->next) {
        ...
    }

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
