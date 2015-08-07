use Test::Stream;
use Test::Stream::Spec qw{
    it tests case before_all after_all around_all before_each after_each
    around_each before_case after_case around_case describe cases
};

use Test::Stream::Workflow qw{
    workflow_build
    workflow_current
    workflow_meta
};

no Test::Stream::Spec;

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
    isa_ok($unit, 'Test::Stream::Workflow::Unit');

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

    mostly_like(
        $unit->primary,
        [
            { name => 'foo', meta => { x => 1 }, primary => $fake, buildup => undef, teardown => undef, modify => undef },
            { name => 'bar', meta => { y => 1 }, primary => $fake, buildup => undef, teardown => undef, modify => undef },
        ],
        "Got tests"
    );

    mostly_like(
        $unit->modify,
        [
            { name => 'a', primary => $fake, buildup => undef, teardown => undef, modify => undef },
            { name => 'b', primary => $fake, buildup => undef, teardown => undef, modify => undef },
        ],
        "Got cases"
    );

    mostly_like(
        $unit->buildup,
        [
            { name => 'ba', primary => $fake, wrap => 0, buildup => undef, teardown => undef, modify => undef },
            { name => 'wa', primary => $fake, wrap => 1, buildup => undef, teardown => undef, modify => undef },
        ],
        "Got before and around all"
    );

    mostly_like(
        $unit->teardown,
        [
            { name => 'aa', primary => $fake, wrap => 0, buildup => undef, teardown => undef, modify => undef },
            { name => 'wa', primary => $fake, wrap => 1, buildup => undef, teardown => undef, modify => undef },
        ],
        "Got after and around all"
    );

    ok(@{$unit->post}, "things to run in post");
};

is($unit->post, undef, "post ran when we popped");

mostly_like(
    $unit->primary,
    [
        {
            name => 'foo', meta => { x => 1 }, modify => undef, primary => $fake,
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
            name => 'bar', meta => { y => 1 }, modify => undef, primary => $fake,
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

mostly_like(
    $unit->modify,
    [
        {
            name => 'a', primary => $fake, modify => undef,
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
            name => 'b', primary => $fake, modify => undef,
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

mostly_like(
    workflow_meta->unit->primary,
    [
        { name => 'for root', primary => $fake },
        { name => 'root describe', primary => [ {name => 'xxx'} ] },
    ],
    "Added test and describe to the root",
);

done_testing;
