use Test2::Bundle::Extended -target => 'Test2::Workflow';
BEGIN { require 't/tools.pl' }
use Test2::Tools::Spec;

use Test2::Workflow qw{
    workflow_build
    workflow_current
    workflow_meta
};

no Test2::Tools::Spec;

ok(!workflow_build, "no current build");

ok(workflow_meta(), "There is a current root");

is(
    workflow_meta->unit->name,
    __PACKAGE__,
    "Got root, name is the package"
);

my $fake = sub { 'fake' };

my $unit = describe blah => sub {
    my $unit = shift;
    isa_ok($unit, 'Test2::Workflow::Unit');

    it    foo => { x => 1 }, $fake;
    tests bar => { y => 1 }, $fake;

    case a => $fake;
    case b => $fake;

    before_all ba => $fake;
    after_all  aa => $fake;
    around_all wa => $fake;

    before_each be => $fake;
    after_each  ae => $fake;
    around_each we => $fake;

    before_case bc => $fake;
    after_case  ac => $fake;
    around_case wc => $fake;

    is($unit, workflow_current(), "Can look at the current build");

    like(
        $unit->primary,
        [
            { name => 'foo', meta => { x => 1 }, primary => $fake, buildup => DNE(), teardown => DNE(), modify => DNE() },
            { name => 'bar', meta => { y => 1 }, primary => $fake, buildup => DNE(), teardown => DNE(), modify => DNE() },
        ],
        "Got tests"
    );

    like(
        $unit->modify,
        [
            { name => 'a', primary => $fake, buildup => DNE(), teardown => DNE(), modify => DNE() },
            { name => 'b', primary => $fake, buildup => DNE(), teardown => DNE(), modify => DNE() },
        ],
        "Got cases"
    );

    like(
        $unit->buildup,
        [
            { name => 'ba', primary => $fake, wrap => 0, buildup => DNE(), teardown => DNE(), modify => DNE() },
            { name => 'wa', primary => $fake, wrap => 1, buildup => DNE(), teardown => DNE(), modify => DNE() },
        ],
        "Got before and around all"
    );

    like(
        $unit->teardown,
        [
            { name => 'aa', primary => $fake, wrap => 0, buildup => DNE(), teardown => DNE(), modify => DNE() },
            { name => 'wa', primary => $fake, wrap => 1, buildup => DNE(), teardown => DNE(), modify => DNE() },
        ],
        "Got after and around all"
    );

    ok(@{$unit->post}, "things to run in post");
};

is($unit->post, undef, "post ran when we popped");

like(
    $unit->primary,
    [
        {
            name => 'foo', meta => { x => 1 }, modify => DNE(), primary => $fake,
            buildup => [
                { name => 'be', primary => $fake, wrap => 0 },
                { name => 'we', primary => $fake, wrap => 1 },
            ],
            teardown => [
                { name => 'ae', primary => $fake, wrap => 0 },
                { name => 'we', primary => $fake, wrap => 1 },
            ],
        },
        {
            name => 'bar', meta => { y => 1 }, modify => DNE(), primary => $fake,
            buildup => [
                { name => 'be', primary => $fake, wrap => 0 },
                { name => 'we', primary => $fake, wrap => 1 },
            ],
            teardown => [
                { name => 'ae', primary => $fake, wrap => 0 },
                { name => 'we', primary => $fake, wrap => 1 },
            ],
        },
    ],
    "Tests got the before/after each"
);

like(
    $unit->modify,
    [
        {
            name => 'a', primary => $fake, modify => DNE(),
            buildup => [
                { name => 'bc', primary => $fake, wrap => 0 },
                { name => 'wc', primary => $fake, wrap => 1 },
            ],
            teardown => [
                { name => 'ac', primary => $fake, wrap => 0 },
                { name => 'wc', primary => $fake, wrap => 1 },
            ],
        },
        {
            name => 'b', primary => $fake, modify => DNE(),
            buildup => [
                { name => 'bc', primary => $fake, wrap => 0 },
                { name => 'wc', primary => $fake, wrap => 1 },
            ],
            teardown => [
                { name => 'ac', primary => $fake, wrap => 0 },
                { name => 'wc', primary => $fake, wrap => 1 },
            ],
        },
    ],
    "Cases for the before/after case blocks"
);

# This is to test that things go to root when there is no current build
tests 'for root' => $fake;
describe 'root describe' => sub { tests 'xxx' => $fake };

like(
    workflow_meta->unit->primary,
    [
        { name => 'for root', primary => $fake },
        { name => 'root describe', primary => [ {name => 'xxx'} ] },
    ],
    "Added test and describe to the root",
);

done_testing;
