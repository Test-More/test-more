package Test::Stream::DeepCheck::State;
use strict;
use warnings;

use Test::Stream::HashBase(
    accessors => [qw/strict seen/],
);

sub init {
    my $self = shift;

    $self->{+SEEN} ||= {};
}

1;
