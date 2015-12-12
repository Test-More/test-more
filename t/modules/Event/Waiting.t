use strict;
use warnings;

use Test2::Tester;
use Test2::Event::Waiting;

my $waiting = Test2::Event::Waiting->new(
    trace => 'fake',
);

ok($waiting, "Created event");
ok($waiting->global, "waiting is global");

done_testing;
