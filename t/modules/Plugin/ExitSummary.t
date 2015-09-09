use Test::Stream::Sync;
use Test::Stream 'Core', 'LoadPlugin', 'Context', 'Intercept', 'Compare' => '*';

my $initial_count = Test::Stream::Sync->hooks;

load_plugin 'ExitSummary';
load_plugin 'ExitSummary';
load_plugin 'ExitSummary';

my $post_count = Test::Stream::Sync->hooks;

is($initial_count, 0, "no hooks initially");
is($post_count, 1, "Added the hook, but only once");

my $summary = Test::Stream::Plugin::ExitSummary->can('summary');

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

done_testing();
