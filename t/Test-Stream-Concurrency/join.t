use Test::Stream::Shim;
use strict;
use warnings;

use Test::CanThread;

use threads;
use Test::More tests => 5;
use Test::Stream::Concurrency wait => 0, join => 1;

ok(my $driver = Test::Stream->shared->concurrency_driver, "Loaded driver");
isa_ok($driver, 'Test::Stream::Concurrency');

is($driver->wait, 0, "wait is unset");
is($driver->join, 1, "join is set");

# Set the thread to send an event after the parent has fallen off.
threads->create(sub {
    sleep 2;
    ok(1, "inside child thread");
});
