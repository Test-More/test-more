use Test::Stream::Shim;
use strict;
use warnings;

use Test::More;
use Test::Stream::Concurrency::Files;

my $sync = Test::Stream->shared->concurrency_driver;
isa_ok($sync, 'Test::Stream::Concurrency::Files');

$sync = Test::Stream::Concurrency::Files->new;
my $tmp = "" . $sync->tempdir;
ok( -d $tmp, "Have a temp dir");

my $structure = { foo => 1 };

$sync->send(orig => [1, 1], dest => [2, 2], events => [$structure]);
my @events = $sync->cull(2, 2);

is_deeply(
    \@events,
    [$structure],
    "Sent and recieved an event!"
);

$sync = undef;

ok(!-d $tmp, "cleaned up temp dir");

done_testing;
