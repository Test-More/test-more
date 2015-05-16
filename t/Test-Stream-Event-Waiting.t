use Test::More;
use strict;
use warnings;

use Test::Stream::Event::Waiting;

my $waiting = Test::Stream::Event::Waiting->new(
    debug => 'fake',
);

ok($waiting, "Created event");
ok($waiting->global, "waiting is global");

done_testing;
