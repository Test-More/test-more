package Test::Stream::Compare::DNE;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
);

sub verify {
    my $self = shift;
    my ($got) = @_;

    return !$got;
}

sub name { "<DOES NOT EXIST>" }
sub operator { '!exists' }

1;
