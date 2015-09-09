use Test::Stream -V1, Intercept, Compare => '*';

imported_ok('intercept');

sub tool { context() };

my %params;
my $ctx = context(level => -1);
my $ictx;
my $events = intercept {
    %params = @_;

    $ictx = tool();
    $ictx->ok(1, 'pass');
    $ictx->ok(0, 'fail');
    my $dbg = Test::Stream::DebugInfo->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__],
    );
    $ictx->hub->finalize($dbg, 1);
};

is(
    \%params,
    {
        context => $ctx,
        hub => $ictx->hub,
    },
    "Passed in some useful params"
);

ok($ctx != $ictx, "Different context inside intercept");

is(@$events, 3, "got 3 events");

$ctx->release;
$ictx->release;

# Test that a skip_all in an intercept does not exit.
$events = intercept {
    $ictx = tool();
    $ictx->plan(0, skip_all => 'cause');
    $ictx->ok(0, "Should not see this");
};

is(@$events, 1, "got 1 event");
isa_ok($events->[0], 'Test::Stream::Event::Plan');

# Test that a bail-out in an intercept does not exit.
$events = intercept {
    $ictx = tool();
    $ictx->bail("The world ends");
    $ictx->ok(0, "Should not see this");
};

is(@$events, 1, "got 1 event");
isa_ok($events->[0], 'Test::Stream::Event::Bail');

$events = intercept {
    $ictx = tool();
};

$ictx->release;

like(
    dies { intercept { die 'foo' } },
    qr/foo/,
    "Exception was propogated"
);

is(
    intercept {
        Test::Stream::Sync->stack->top->set_no_ending(0);
        ok(1);
    },
    array { event Ok => {}; event Plan => {max => 1} },
    "finalize was called"
);

is(
    intercept {
        Test::Stream::Sync->stack->top->set_no_ending(0);
        ok(1);
        done_testing;
    },
    array { event Ok => {}; event Plan => {max => 1}; end },
    "finalize was called, but only one plan"
);

done_testing;
