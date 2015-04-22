use strict;
use warnings;

use Test::More;
use Test::Stream::Concurrency(wait => undef, join => undef);

my $driver = Test::Stream->shared->concurrency_driver;
is_deeply(
    [$driver->configure],
    [wait => undef, join => undef],
    "Not Set"
);

Test::Stream::Concurrency->import(join => 0);
is_deeply(
    [$driver->configure],
    [wait => 1, join => 0],
    "Updated, join was specified, wait is default"
);

# Make sure it does not try to set it again!
Test::Stream::Concurrency->import();
is_deeply(
    [$driver->configure],
    [wait => 1, join => 0],
    "No Change"
);

my $sync = Test::Stream::Concurrency->spawn();
is_deeply(
    [$sync->configure],
    [wait => 1, join => 1],
    "Defaults"
);

$sync = Test::Stream::Concurrency->spawn(wait => undef, join => undef);
is_deeply(
    [$sync->configure],
    [wait => undef, join => undef],
    "Not specified, can be updated later"
);
is_deeply(
    [$sync->configure(join => 1, wait => 0)],
    [wait => 0, join => 1],
    "Updated"
);

$sync = Test::Stream::Concurrency->spawn(wait => 1, join => 1);
is_deeply(
    [$sync->configure],
    [wait => 1, join => 1],
    "Set to true"
);

$sync = Test::Stream::Concurrency->spawn(wait => 0, join => 0);
is_deeply(
    [$sync->configure],
    [wait => 0, join => 0],
    "Set to false"
);

done_testing;
