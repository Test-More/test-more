use Test::Stream::Shim;
use strict;
use warnings;

use Test::CanFork;

use Test::More tests => 5;
use Test::Stream::Concurrency wait => 1, join => 0;

ok(my $driver = Test::Stream->shared->concurrency_driver, "Loaded driver");
isa_ok($driver, 'Test::Stream::Concurrency');

is($driver->wait, 1, "wait is set");
is($driver->join, 0, "join is unset");

my $pid = fork;
die "Failed to fork!" unless defined $pid;

# Set the child process to send an event after the parent has fallen off the
# edge.
unless ($pid) {
    sleep 2;
    ok(1, "Inside child process");
    exit 0;
}
