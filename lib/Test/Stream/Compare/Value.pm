package Test::Stream::Compare::Value;
use strict;
use warnings;

use Scalar::Util qw/looks_like_number/;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/input/],
);

sub name {
    my $self = shift;
    my $in = $self->{+INPUT};
    return '<UNDEF>' unless defined $in;
    return "$in";
}

sub operator {
    my $self = shift;

    return '' unless @_;

    my ($got) = @_;
    my $input = $self->{+INPUT};

    return '' if defined($input) xor defined($got);
    return '==' unless defined($input) && defined($got);
    return '==' if looks_like_number($got) && looks_like_number($input);
    return 'eq';
}

sub verify {
    my $self = shift;
    my ($got) = @_;

    my $op = $self->operator($got);

    return !defined($got) unless defined($self->{+INPUT});
    return 0 unless defined($got);

    my $input = $self->{+INPUT};

    return $input == $got if $op eq '==';
    return $input eq $got;
}

1;
