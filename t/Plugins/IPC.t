package XXX;

use strict;
use warnings;

use Test::Stream qw/IPC/;

my @drivers;
BEGIN { @drivers = Test::Stream::IPC->drivers };

use Test::Stream '-Tester';

is_deeply(
    \@drivers,
    ['Test::Stream::IPC::Files'],
    "Got default driver"
);

not_imported('cull');
load_plugin IPC => [qw/-cull/];
imported('cull');

ok(!Test::Stream::IPC->polling_enabled, "polling not enabled");
load_plugin IPC => [qw/-poll/];
ok(Test::Stream::IPC->polling_enabled, "enabled polling");

ok(lives { cull() }, "cull runs");

like(
    dies { load_plugin IPC => ['-foo'] },
    qr/Invalid parameters: '-foo'/,
    "Die with invalid arguments"
);

use Data::Dumper;

my @LOAD;
local @INC = (sub {
    my ($sub, $file) = @_;
    push @LOAD => $file;

    return \"1;" if $file =~ m/Real/;
    return;
});

ok( lives { load_plugin IPC => ['FakeDriver'] }, "Did not die with a bad driver" );
ok( lives { load_plugin IPC => ['RealDriver'] }, "Did not die with a good driver" );
ok( lives { load_plugin IPC => ['+Other::FakeDriver'] }, "Did not die with a fully qualified driver" );

is_deeply(
    \@LOAD,
    [
        'Test/Stream/IPC/FakeDriver.pm',
        'Test/Stream/IPC/RealDriver.pm',
        'Other/FakeDriver.pm',
    ],
    "Tried to load the correct drivers, in order"
);

is_deeply(
    [ Test::Stream::IPC->drivers ],
    [
        'Test::Stream::IPC::Files',
        'Test::Stream::IPC::RealDriver',
    ],
    "Correct driver was registered"
);

done_testing;
