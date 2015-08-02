use strict;
use warnings;

use Test::Stream::IPC;

my @drivers;
BEGIN { @drivers = Test::Stream::IPC->drivers };

use Test::Stream;

is_deeply(
    \@drivers,
    ['Test::Stream::IPC::Files'],
    "Got default driver"
);

done_testing;
