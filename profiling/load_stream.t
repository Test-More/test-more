use strict;
use warnings;

use Config;
BEGIN { require base; require parent; require Exporter};
use Carp;
use Scalar::Util;
use List::Util;

use Test::Stream 'Core';

ok(1, "an ok");

done_testing;
