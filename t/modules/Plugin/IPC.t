package XXX;

use strict;
use warnings;

use Test::Stream qw/IPC/;

my @drivers;
BEGIN { @drivers = Test::Stream::IPC->drivers };

use Test::Stream qw/-V1 -Tester/;

is(
    \@drivers,
    ['Test::Stream::IPC::Files'],
    "Got default driver"
);

not_imported_ok('cull');
load_plugin IPC => [qw/-cull/];
imported_ok('cull');

ok(!Test::Stream::IPC->polling_enabled, "polling not enabled");
load_plugin IPC => [qw/-poll/];
ok(Test::Stream::IPC->polling_enabled, "enabled polling");

ok(lives { cull() }, "cull runs");

like(
    dies { load_plugin IPC => ['-foo'] },
    qr/Invalid parameters: '-foo'/,
    "Die with invalid arguments"
);

my @LOAD;
my %results;
{
    local @INC = (sub {
        my ($sub, $file) = @_;
        push @LOAD => $file;
        return;
    }, 't/lib', 'lib');

    %results = (
        'FakeDriver'        => lives { load_plugin IPC => ['FakeDriver'] },
        'RealDriver'        => lives { load_plugin IPC => ['RealDriver'] },
        'Other::FakeDriver' => lives { load_plugin IPC => ['+Other::FakeDriver'] },
    );
}

ok( $results{'FakeDriver'}, "Did not die with a bad driver" );
ok( $results{'RealDriver'}, "Did not die with a good driver" );
ok( $results{'Other::FakeDriver'}, "Did not die with a fully qualified driver" );

is(
    \@LOAD,
    [
        'Test/Stream/IPC/FakeDriver.pm',
        'Test/Stream/IPC/RealDriver.pm',
        'Other/FakeDriver.pm',
    ],
    "Tried to load the correct drivers, in order"
);

is(
    [ Test::Stream::IPC->drivers ],
    [
        'Test::Stream::IPC::Files',
        'Test::Stream::IPC::RealDriver',
    ],
    "Correct driver was registered"
);

done_testing;
