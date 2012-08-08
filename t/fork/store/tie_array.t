use strict;
use warnings;
use Test::SharedFork::Store;
use Test::SharedFork::Array;
use Test::More tests => 1;

my $store = Test::SharedFork::Store->new();
tie my @x, 'Test::SharedFork::Array', $store, 'array';
$x[0] = 3;
is $x[0], 3;

