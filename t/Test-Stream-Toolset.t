use strict;
use warnings;

use Test::More 'modern';

use ok 'Test::Stream::Toolset';

can_ok(__PACKAGE__, qw/is_tester init_tester context/);

done_testing;
