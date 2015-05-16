use Test::More;
use strict;
use warnings;

use Test::Stream::Event::Bail;

use Test::Stream::TAP qw/OUT_STD/;

my $bail = Test::Stream::Event::Bail->new(
    debug => 'fake',
    reason => 'evil',
);

is_deeply(
    [$bail->to_tap(1)],
    [[OUT_STD, "Bail out!  evil\n" ]],
    "Got tap"
);

$bail->set_quiet(1);
is_deeply(
    [$bail->to_tap(1)],
    [],
    "quiet tap = no tap"
);

is($bail->terminate, 255, "Bail will cause the test to exit.");
is($bail->global, 1, "Bail is global, everything should bail");

require Test::Stream::State;
my $state = Test::Stream::State->new;
ok($state->is_passing, "passing");
ok(!$state->failed, "no failures");

$bail->update_state($state);

ok(!$state->is_passing, "not passing");
ok($state->failed, "failure added");

done_testing;
