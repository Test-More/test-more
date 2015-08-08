package Test::Stream::Compare::Meta;
use strict;
use warnings;

use Test::Stream::Delta;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/items/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype blessed/;

sub init {
    my $self = shift;
    $self->{+ITEMS} ||= [];
}

sub name { '<META CHECKS>' }

sub verify { 1 }

sub add_prop {
    my $self = shift;
    my ($name, $check) = @_;

    croak "prop name is required"
        unless defined $name;

    my $meth = "get_prop_$name";
    croak "'$name' is not a known property"
        unless $self->can($meth);

    push @{$self->{+ITEMS}} => [$meth, $check, $name];
}

sub deltas {
    my $self = shift;
    my ($got, $convert, $seen) = @_;

    my @deltas;
    my $items = $self->{+ITEMS};

    for my $set (@$items) {
        my ($meth, $check, $name) = @$set;

        $check = $convert->($check);

        my $val = $self->$meth($got);

        push @deltas => $check->run([META => $name], $val, $convert, $seen);
    }

    return @deltas;
}

sub get_prop_blessed { blessed($_[1]) }

sub get_prop_reftype { reftype($_[1]) }

sub get_prop_this { $_[1] }

sub get_prop_size {
    my $self = shift;
    my ($it) = @_;

    my $type = reftype($it) || '';

    return scalar @$it      if $type eq 'ARRAY';
    return scalar keys %$it if $type eq 'HASH';
    return undef;
}

1;
