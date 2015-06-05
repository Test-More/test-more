use strict;
use warnings;

use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;
use Test::Stream;

can_ok(__PACKAGE__, qw/CAN_FORK CAN_THREAD/);

# Make sure running them does not die
# We cannot really do much to test these.
CAN_THREAD();
CAN_FORK();

done_testing;
