package Test::Stream::Compare::Scalar;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/item/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype/;

sub init {
    my $self = shift;

    my $ref = $self->{+ITEM} || croak "'item' is a required attribute";
}

sub name { '<SCALAR>' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    return 0 unless $got;
    return 0 unless ref($got);
    return 0 unless reftype($got) eq 'SCALAR';
    return 1;
}

sub deltas {
    my $self = shift;
    my ($got, $convert, $seen) = @_;

    my $item = $self->{+ITEM};
    my $check = $convert->($item);

    return ($check->run(['SCALAR' => '$*'], $$got, $convert, $seen));
}

1;
