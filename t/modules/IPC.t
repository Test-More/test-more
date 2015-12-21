use strict;
use warnings;

use Test2::IPC qw/cull/;

BEGIN { require "t/tools.pl" };
use Test2::API qw/context/;

is_deeply(
    [Test2::Global::test2_ipc_drivers],
    ['Test2::IPC::Driver::Files'],
    "Default driver"
);

ok(__PACKAGE__->can('cull'), "Imported cull");

done_testing;
