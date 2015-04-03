use strict;
use warnings;

use Test::More;

use ok 'Test::Stream::Event::Plan';

sub exception(&) {
    local $@;
    my $code = shift;
    my $ret = eval { $code->(); 1 };
    return if $ret;
    return $@;
}

my $e = exception { Test::Stream::Event::Plan->new(context => 'fake', created => 'fake') };
like($e, qr/No number of tests specified/, "Need a number");

$e = exception { Test::Stream::Event::Plan->new(context => 'fake', created => 'fake', reason => 'foo') };
like($e, qr/Cannot have a reason without a directive/, "Reason needs a directive");

$e = exception { Test::Stream::Event::Plan->new(context => 'fake', created => 'fake', reason => 'foo', directive => 'foo') };
like($e, qr/'foo' is not a valid plan directive/, "Invalid directive");


my $one = Test::Stream::Event::Plan->new(context => 'fake', created => 'fake', max => 1);
is_deeply(
    $one->to_tap,
    [
        Test::Stream::Event::Plan::OUT_STD,
        "1..1\n",
    ],
    "Simple plan"
);

$one->set_max(20);
is_deeply(
    $one->to_tap,
    [
        Test::Stream::Event::Plan::OUT_STD,
        "1..20\n",
    ],
    "Simple plan 2"
);

$one->set_max(0);
$one->set_directive('SKIP');
is_deeply(
    $one->to_tap,
    [
        Test::Stream::Event::Plan::OUT_STD,
        "1..0 # SKIP\n",
    ],
    "Skip"
);

$one->set_reason('I said so');
is_deeply(
    $one->to_tap,
    [
        Test::Stream::Event::Plan::OUT_STD,
        "1..0 # SKIP I said so\n",
    ],
    "Skip with reason"
);

$one = Test::Stream::Event::Plan->new(
    context => 'fake',
    created => 'fake',
    directive => 'skip_all',
    max => 1,
);
is($one->directive, 'SKIP', "translated skip_all to SKIP");

$one = Test::Stream::Event::Plan->new(
    context => 'fake',
    created => 'fake',
    directive => 'no_plan',
    max => 1,
);
is($one->directive, 'NO PLAN', "translated no_plan to 'NO PLAN'");

done_testing;
