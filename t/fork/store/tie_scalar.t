use strict;
use warnings;
use Test::SharedFork::Store;
use Test::SharedFork::Scalar;
use Test::More tests => 1;

my $store = Test::SharedFork::Store->new();
tie my $x, 'Test::SharedFork::Scalar', $store, 'scalar';
$x = 3;
is $x, 3;

