use Test::Stream -V1;

use Test::Stream::Event::Bail;

use Test::Stream::Formatter::TAP qw/OUT_STD/;

my $bail = Test::Stream::Event::Bail->new(
    debug => 'fake',
    reason => 'evil',
);

ok($bail->causes_fail, "balout always causes fail.");

warns {
    is(
        [$bail->to_tap(1)],
        [[OUT_STD, "Bail out!  evil\n" ]],
        "Got tap"
    );
};

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
