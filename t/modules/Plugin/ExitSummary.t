use strict;
use warnings;
# HARNESS-NO-PRELOAD

use Test2::API;

my $initial_count;
BEGIN { $initial_count = Test2::API::test2_list_exit_callbacks() }

use Test2::Tools::Basic;
use Test2::API qw/intercept context/;
use Test2::Tools::Compare qw/array event end is like/;

use Test2::Plugin::ExitSummary;
use Test2::Plugin::ExitSummary;
use Test2::Plugin::ExitSummary;

my $post_count = Test2::API::test2_list_exit_callbacks();

is($initial_count, 0, "no hooks initially");
is($post_count, 1, "Added the hook, but only once");

my $summary = Test2::Plugin::ExitSummary->can('summary');

my $exit = 0;
my $new = 0;

like(
    intercept {
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array { event Diag => {message => 'No tests run!'}; end },
    "No tests run"
);

like(
    intercept {
        plan 1;
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array {
        event Plan => { max => 1 };
        event Diag => {message => 'No tests run!'};
        event Diag => {message => 'Did not follow plan: expected 1, ran 0.'};
        end
    },
    "No tests run, bad plan"
);

like(
    intercept {
        ok(1);
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array {
        event Ok => { pass => 1 };
        event Diag => {message => 'Tests were run but no plan was declared and done_testing() was not seen.'};
        end
    },
    "Tests, but no plan"
);

$exit = 123;
$new = 123;
like(
    intercept {
        plan 1;
        ok(1);
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array {
        event Plan => { max => 1 };
        event Ok => { pass => 1 };
        event Diag => {message => 'Looks like your test exited with 123 after test #1.'};
        end
    },
    "Bad exit code"
);

$exit = 0;
$new = 0;
like(
    intercept {
        plan 2;
        ok(1);
        ok(0);
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array {
        event Plan => { max => 2 };
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
        event Diag => {};  # "Failed test" diagnostic from ok(0)
        event Diag => {message => 'Looks like you failed 1 test of 2.'};
        end
    },
    "Failed test count reported"
);

like(
    intercept {
        plan 3;
        ok(0);
        ok(0);
        ok(1);
        my $ctx = context(level => -1);
        $summary->($ctx, $exit, \$new);
        $ctx->release;
    },
    array {
        event Plan => { max => 3 };
        event Ok => { pass => 0 };
        event Diag => {};  # "Failed test" diagnostic from first ok(0)
        event Ok => { pass => 0 };
        event Diag => {};  # "Failed test" diagnostic from second ok(0)
        event Ok => { pass => 1 };
        event Diag => {message => 'Looks like you failed 2 tests of 3.'};
        end
    },
    "Failed test count reported (plural)"
);

done_testing();
