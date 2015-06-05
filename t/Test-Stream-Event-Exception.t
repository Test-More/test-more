use Test::Stream;
use strict;
use warnings;

use Test::Stream::Event::Exception;

use Test::Stream::TAP qw/OUT_ERR/;

my $exception = Test::Stream::Event::Exception->new(
    debug => 'fake',
    error => "evil at lake_of_fire.t line 6\n",
);

is_deeply(
    [$exception->to_tap(1)],
    [[OUT_ERR, "evil at lake_of_fire.t line 6\n" ]],
    "Got tap"
);

require Test::Stream::State;
my $state = Test::Stream::State->new;
ok($state->is_passing, "passing");
ok(!$state->failed, "no failures");

$exception->update_state($state);

ok(!$state->is_passing, "not passing");
ok($state->failed, "failure added");

done_testing;
