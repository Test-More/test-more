use strict;
use warnings;

use Test::Stream::IPC;
use Test::Stream;

is_deeply(
    [Test::Stream::IPC->drivers],
    ['Test::Stream::IPC::Files'],
    "Got default driver"
);

done_testing;
