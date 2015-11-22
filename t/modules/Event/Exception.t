use Test::Stream -V1;

use Test::Stream::Event::Exception;

use Test::Stream::Formatter::TAP qw/OUT_ERR/;

my $exception = Test::Stream::Event::Exception->new(
    debug => 'fake',
    error => "evil at lake_of_fire.t line 6\n",
);

ok($exception->causes_fail, "Exception events always cause failure");

warns {
    is(
        [$exception->to_tap(1)],
        [[OUT_ERR, "evil at lake_of_fire.t line 6\n" ]],
        "Got tap"
    );
};

require Test::Stream::State;
my $state = Test::Stream::State->new;
ok($state->is_passing, "passing");
ok(!$state->failed, "no failures");

$exception->update_state($state);

ok(!$state->is_passing, "not passing");
ok($state->failed, "failure added");

done_testing;
