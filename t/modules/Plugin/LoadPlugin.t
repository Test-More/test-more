use strict;
use warnings;

use Test::Stream 'LoadPlugin';

load_plugin 'More';

ok(1, "ok was imported");

done_testing();
