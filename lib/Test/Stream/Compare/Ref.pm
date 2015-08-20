package Test::Stream::Compare::Ref;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/input/],
);

use Scalar::Util qw/reftype/;
use Carp qw/croak/;

sub init {
    my $self = shift;

    croak "'input' is a required attribute"
        unless $self->{+INPUT};

    croak "'input' must be a reference, got '" . $self->{+INPUT} . "'"
        unless ref $self->{+INPUT};
}

sub name { $_[0]->{+INPUT} . "" }
sub operator { '==' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    my $in = $self->{+INPUT};
    return 0 unless ref $in;
    return 0 unless ref $got;

    return $in == $got;
}

1;
