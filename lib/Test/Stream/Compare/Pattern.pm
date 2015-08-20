package Test::Stream::Compare::Pattern;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/pattern negate/],
);

use Carp qw/croak/;

sub init {
    my $self = shift;

    croak "'pattern' is a required attribute" unless $self->{+PATTERN};
}

sub name { shift->{+PATTERN} }

sub operator { shift->{+NEGATE} ? '!~' : '=~' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    return 0 if ref $got;

    if ($self->{+NEGATE}) {
        return 1 unless defined($got);
        return $got !~ $self->{+PATTERN};
    }
    else {
        return 0 unless defined($got);
        return $got =~ $self->{+PATTERN};
    }
}

1;
