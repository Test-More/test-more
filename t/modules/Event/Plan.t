use Test::Stream -V1;
use strict;
use warnings;

use Test::Stream::Event::Plan;
use Test::Stream::DebugInfo;
use Test::Stream::State;

use Test::Stream::Formatter::TAP qw/OUT_STD/;

my $plan = Test::Stream::Event::Plan->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    max => 100,
);

warns {
    is(
        [$plan->to_tap(1)],
        [[OUT_STD, "1..100\n"]],
        "Got tap"
    );
};
ok(!$plan->global, "regular plan is not a global event");
my $state = Test::Stream::State->new;
$plan->update_state($state);
is($state->plan, 100, "set plan in state");
is($plan->terminate, undef, "No terminate for normal plan");

$plan->set_max(0);
$plan->set_directive('SKIP');
$plan->set_reason('foo');
warns {
    is(
        [$plan->to_tap(1)],
        [[OUT_STD, "1..0 # SKIP foo\n"]],
        "Got tap for skip_all"
    );
};
ok($plan->global, "plan is global on skip all");
$state = Test::Stream::State->new;
$plan->update_state($state);
is($state->plan, 'SKIP', "set plan in state");
is($plan->terminate, 0, "Terminate 0 on skip_all");

$plan->set_max(0);
$plan->set_directive('NO PLAN');
$plan->set_reason(undef);
$state = Test::Stream::State->new;
$plan->update_state($state);
is($state->plan, 'NO PLAN', "set plan in state");
is($plan->terminate, undef, "No terminate for no_plan");
$plan->set_max(100);
$plan->set_directive(undef);
$plan->update_state($state);
is($state->plan, '100', "Update plan in state if it is 'NO PLAN'");


$plan = Test::Stream::Event::Plan->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    max => 0,
    directive => 'skip_all',
);
is($plan->directive, 'SKIP', "Change skip_all to SKIP");
warns {
    is(
        [$plan->to_tap],
        [[OUT_STD, "1..0 # SKIP\n"]],
        "SKIP without reason"
    );
};

$plan = Test::Stream::Event::Plan->new(
    debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    max => 0,
    directive => 'no_plan',
);
is($plan->directive, 'NO PLAN', "Change no_plan to 'NO PLAN'");
ok(!$plan->global, "NO PLAN is not global");
warns {
    is(
        [$plan->to_tap],
        [],
        "NO PLAN"
    );
};

like(
    dies {
        $plan = Test::Stream::Event::Plan->new(
            debug     => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
            max       => 0,
            directive => 'foo',
        );
    },
    qr/'foo' is not a valid plan directive/,
    "Invalid Directive"
);

like(
    dies {
        $plan = Test::Stream::Event::Plan->new(
            debug  => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
            max    => 0,
            reason => 'foo',
        );
    },
    qr/Cannot have a reason without a directive!/,
    "Reason without directive"
);

like(
    dies {
        $plan = Test::Stream::Event::Plan->new(
            debug  => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
        );
    },
    qr/No number of tests specified/,
    "Nothing to do"
);

like(
    dies {
        $plan = Test::Stream::Event::Plan->new(
            debug  => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
            max => 'skip',
        );
    },
    qr/Plan test count 'skip' does not appear to be a valid positive integer/,
    "Max must be an integer"
);

done_testing;
