package Test::Stream::DeepCheck::Events;
use strict;
use warnings;

use Test::Stream::DeepCheck::Array;
use Test::Stream::HashBase(
    base => 'Test::Stream::DeepCheck::Array',
);

sub as_string { "Arrayref of events" }

1;
