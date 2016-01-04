use strict;
use warnings;
use Test::More;

my $count = $ENV{OK_COUNT} || 100000;
plan(tests => $count);

ok(1, "an ok") for 1 .. $count;

1;
