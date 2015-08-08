package Test::Stream::Compare::Wildcard;
use strict;
use warnings;

use Test::Stream::Compare();
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/expect/],
);

1;
