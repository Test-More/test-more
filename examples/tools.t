use strict;
use warnings;

use Test2::IPC;
BEGIN { require "t/tools.pl" };

use Test2::API qw/context intercept test2_stack/;

ok(__PACKAGE__->can($_), "imported '$_\()'") for qw{
    ok
    is   isnt
    like unlike
    diag note

    is_deeply

    warnings
    exception

    plan
    skip_all
    done_testing
};

ok(1, "'ok' Test");
is("foo", "foo", "'is' test");
is(undef, undef, "'is' undef test");
isnt("foo", "bar", "'isnt' test");
isnt("foo", undef, "'isnt' undef test 1");
isnt(undef, "foo", "'isnt' undef test 2");
like("foo", qr/o/, "'like' test");
unlike("foo", qr/a/, "'unlike' test");
diag("Testing Diag");
note("Testing Note");

my $str = "abc";
is_deeply(
    { a => 1, b => 2, c => { ref => \$str, obj => bless({x => 1}, 'XXX'), array => [1, 2, 3]}},
    { a => 1, b => 2, c => { ref => \$str, obj =>       {x => 1},         array => [1, 2, 3]}},
    "'is_deeply' test"
);

is_deeply(
    warnings { warn "aaa\n"; warn "bbb\n" },
    [ "aaa\n", "bbb\n" ],
    "Got warnings"
);

is_deeply(
    warnings { 1 },
    [],
    "no warnings"
);

is(exception { die "foo\n" }, "foo\n", "got exception");
is(exception { 1 }, undef, "no exception");

my $events = intercept {
    plan 8;

    ok(0, "'ok' Test");
    is("foo", "bar", "'is' test");
    isnt("foo", "foo", "'isnt' test");
    like("foo", qr/a/, "'like' test");
    unlike("foo", qr/o/, "'unlike' test");

    diag("Testing Diag");
    note("Testing Note");

    is_deeply(
        { a => 1, b => 2, c => {}},
        { a => 1, b => 2, c => []},
        "'is_deeply' test"
    );
};

is(@$events, 9, "got 9 events");

my ($plan, $ok, $is, $isnt, $like, $unlike, $diag, $note, $is_deeply) = @$events;

ok($plan->isa('Test2::Event::Plan'), "got plan");
is($plan->max, 8, "planned for 8 oks");

ok($ok->isa('Test2::Event::Ok'), "got 'ok' result");
is($ok->pass, 0, "'ok' test failed");

ok($is->isa('Test2::Event::Ok'), "got 'is' result");
is($is->pass, 0, "'is' test failed");

ok($isnt->isa('Test2::Event::Ok'), "got 'isnt' result");
is($isnt->pass, 0, "'isnt' test failed");

ok($like->isa('Test2::Event::Ok'), "got 'like' result");
is($like->pass, 0, "'like' test failed");

ok($unlike->isa('Test2::Event::Ok'), "got 'unlike' result");
is($unlike->pass, 0, "'unlike' test failed");

ok($is_deeply->isa('Test2::Event::Ok'), "got 'is_deeply' result");
is($is_deeply->pass, 0, "'is_deeply' test failed");

ok($diag->isa('Test2::Event::Diag'), "got 'diag' result");
is($diag->message, "Testing Diag", "got diag message");

ok($note->isa('Test2::Event::Note'), "got 'note' result");
is($note->message, "Testing Note", "got note message");

$events = intercept {
    skip_all 'because';
    ok(0, "should not see me");
    die "should not happen";
};

is(@$events, 1, "1 event");
ok($events->[0]->isa('Test2::Event::Plan'), "got plan");
is($events->[0]->directive, 'SKIP', "plan is skip");
is($events->[0]->reason, 'because', "skip reason");

$events = intercept {
    is(undef, "");
    is("", undef);

    isnt(undef, undef);

    like(undef, qr//);
    unlike(undef, qr//);
};

is(@$events, 5, "5 events");
ok(!$_->pass, "undef test - should not pass") for @$events;

sub tool { context() };

my %params;
my $ctx = context(level => -1);
my $ictx;
$events = intercept {
    %params = @_;

    $ictx = tool();
    $ictx->ok(1, 'pass');
    $ictx->ok(0, 'fail');
    my $trace = Test2::Context::Trace->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__],
    );
    $ictx->hub->finalize($trace, 1);
};

is_deeply(
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

# Test that a bail-out in an intercept does not exit.
$events = intercept {
    $ictx = tool();
    $ictx->bail("The world ends");
    $ictx->ok(0, "Should not see this");
};

is(@$events, 1, "got 1 event");
ok($events->[0]->isa('Test2::Event::Bail'), "got the bail");

$events = intercept {
    $ictx = tool();
};

$ictx->release;

like(
    exception { intercept { die 'foo' } },
    qr/foo/,
    "Exception was propagated"
);

$events = intercept {
    test2_stack()->top->set_no_ending(0);
    ok(1);
};

is(@$events, 2, "2 events");
ok($events->[0]->isa('Test2::Event::Ok'), "got ok");
ok($events->[1]->isa('Test2::Event::Plan'), "finalize was called");

$events = intercept {
    test2_stack()->top->set_no_ending(0);
    ok(1);
    done_testing;
};

is(@$events, 2, "2 events");
ok($events->[0]->isa('Test2::Event::Ok'), "got ok");
ok($events->[1]->isa('Test2::Event::Plan'), "finalize was called (only 1 plan)");

done_testing;
