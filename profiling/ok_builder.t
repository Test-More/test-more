use strict;
use warnings;
use Test::More;

my $count = 100000;
plan(tests => $count);

ok(1, "an ok") for 1 .. $count;

1;
