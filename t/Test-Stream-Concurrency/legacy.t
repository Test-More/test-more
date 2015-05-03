use Test::Stream::Shim;
use strict;
use warnings;

use Test::CanThread;

use threads;
use Test::More;

# This test ensures that concurrency loads when threads are loaded before
# Test::More. It also tests that wait and join are not set (undef, not 1 or 0)
# so that they can be set later if desired, but do not run by default.

ok(my $driver = Test::Stream->shared->concurrency_driver, "Loaded driver");
isa_ok($driver, 'Test::Stream::Concurrency');

is($driver->wait, undef, "wait is undefined");
is($driver->join, undef, "join is undefined");

$driver->configure(wait => 1);
is($driver->wait, 1, "Able to set wait once");

$driver->configure(join => 0);
is($driver->join, 0, "Able to set join once");

my $set = eval { $driver->configure(wait => 0); 1 };
my $err = $@;
is($driver->wait, 1, "Cannot change it after it is defined");
ok(!$set, "eval failed");
like($err, qr/wait is already set to 1, cannot set it to 0/, "proper error");

$set = eval { $driver->configure(join => 1); 1 };
$err = $@;
is($driver->join, 0, "Cannot change it after it is defined");
ok(!$set, "eval failed");
like($err, qr/join is already set to 0, cannot set it to 1/, "Proper error");

done_testing;
