use strict;
use warnings;

use Test::More tests => 3;
use Test::SharedFork;

ok(1, 'one');
if (!Test::SharedFork::fork) {
    ok(1, 'two');
    exit 0;
}
1 while wait == -1;
ok(1, 'three');

