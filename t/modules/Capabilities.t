use Test::Stream -V1;

use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;

can_ok(__PACKAGE__, qw/CAN_FORK CAN_THREAD/);

# Make sure running them does not die
# We cannot really do much to test these.
CAN_THREAD();
CAN_FORK();

done_testing;
