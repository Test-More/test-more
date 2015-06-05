use Test::Stream;
use Test::Stream::Tester;
use Test::Stream::Interceptor qw/warns dies/;

can_ok( __PACKAGE__, qw{
    ok pass fail
    is isnt
    like unlike
    cmp_ok
    is_deeply
    mostly_like
    diag note
    plan skip_all done_testing
    BAIL_OUT
    todo skip
    can_ok isa_ok does_ok ref_ok
});

ok(!__PACKAGE__->can('context'), "context not exported by default");
Test::Stream->import('context');
can_ok(__PACKAGE__, qw/context/);

like(
    dies {eval "\$x = 'foo'" || die $@ },
    qr/"\$x" requires explicit package name/,
    "strict appears to be enabled"
);

mostly_like(
    warns { my $x; $x =~ m/foo/ },
    [ qr/uninitialized value.*in pattern match/ ],
    "warnings appear to be enabled"
);

pass('Testing Pass');

my @lines;
events_are(
    intercept {
        pass('pass');               push @lines => __LINE__;
        fail('fail');               push @lines => __LINE__;
        fail('fail', 'added diag'); push @lines => __LINE__;
    },
    events {
        event Ok => sub {
            event_call pass => 1;
            event_call name => 'pass';

            event_file    __FILE__;
            event_package __PACKAGE__;
            event_line    $lines[0];
            event_sub     'Test::Stream::pass';
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [ qr/Failed test 'fail'.*line $lines[1]/s ];

            event_file    __FILE__;
            event_package __PACKAGE__;
            event_line    $lines[1];
            event_sub     'Test::Stream::fail';
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [ qr/Failed test 'fail'.*line $lines[2]/s, 'added diag' ];

            event_file    __FILE__;
            event_package __PACKAGE__;
            event_line    $lines[2];
            event_sub     'Test::Stream::fail';
        };
        end_events;
    },
    "Got expected events for 'pass' and 'fail'"
);

ok(1, 'Testing ok');

@lines = ();
events_are(
    intercept {
        ok(1, 'pass', 'invisible diag'); push @lines => __LINE__;
        ok(0, 'fail');                   push @lines => __LINE__;
        ok(0, 'fail', 'added diag');     push @lines => __LINE__;
    },
    events {
        event Ok => sub {
            event_call pass => 1;
            event_call name => 'pass';
            event_call diag => undef;
            event_line $lines[0];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [ qr/Failed test 'fail'.*line $lines[1]/s ];
            event_trace 'at ' . __FILE__ . " line $lines[1]";
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [ qr/Failed test 'fail'.*line $lines[2]/s, 'added diag' ];
            event_trace 'at ' . __FILE__ . " line $lines[2]";
        };
        end_events;
    },
    "Got expected events for 'ok'"
);

is(1, 1, "testing is");
is('foo', 'foo', "testing is again");

@lines = ();
events_are(
    intercept {
        is('foo', 'foo', "pass"); push @lines => __LINE__;
        is('foo', 'bar', "fail"); push @lines => __LINE__;
        is('foo', 'baz', "fail", 'extra diag'); push @lines => __LINE__;
    },
    events {
        event Ok => sub {
            event_call pass => 1;
            event_call name => 'pass';
            event_call diag => undef;
            event_line $lines[0];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[1]/s,
                "Failed check: 'foo' eq 'bar'"
            ];
            event_trace 'at ' . __FILE__ . " line $lines[1]";
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[2]/s,
                "Failed check: 'foo' eq 'baz'",
                'extra diag'
            ];
            event_trace 'at ' . __FILE__ . " line $lines[2]";
        };
        end_events;
    },
    "Got expected events for 'is'"
);

@lines = ();
events_are(
    intercept {
        isnt('foo', 'bar', "pass"); push @lines => __LINE__;
        isnt('foo', 'foo', "fail"); push @lines => __LINE__;
        isnt('foo', 'foo', "fail", 'extra diag'); push @lines => __LINE__;
    },
    events {
        event Ok => sub {
            event_call pass => 1;
            event_call name => 'pass';
            event_call diag => undef;
            event_line $lines[0];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[1]/s,
                "Failed check: 'foo' ne 'foo'"
            ];
            event_trace 'at ' . __FILE__ . " line $lines[1]";
        };
        event Ok => sub {
            event_call pass => 0;
            event_call name => 'fail';
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[2]/s,
                "Failed check: 'foo' ne 'foo'",
                'extra diag'
            ];
            event_trace 'at ' . __FILE__ . " line $lines[2]";
        };
        end_events;
    },
    "Got expected events for 'isnt'"
);

note "Testing Diag";

events_are(
    intercept {
        diag "foo";
        diag "foo", ' ', "bar";
    },
    events {
        event Diag => { message => 'foo' };
        event Diag => { message => 'foo bar' };
    },
    "Got expected events for diag"
);

note "Testing Note";

events_are(
    intercept {
        note "foo";
        note "foo", ' ', "bar";
    },
    events {
        event Note => { message => 'foo' };
        event Note => { message => 'foo bar' };
    },
    "Got expected events for note"
);

like(
    dies { like("foo", "bar", 'fail') },
    qr/^val must be a regex when op is '=~', got: 'bar'/,
    "Tesing like"
);

@lines = ();
events_are(
    intercept {
        like("foo", qr/foo/, 'pass'); push @lines => __LINE__;
        like("foo", qr/bar/, 'fail'); push @lines => __LINE__;
        like("foo", qr/bar/, 'fail', 'extra diag'); push @lines => __LINE__;
    },
    events {
        event Ok => sub { event_call pass => 1 };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[1]/s,
                "Failed check: 'foo' =~ " . qr/bar/,
            ];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[2]/s,
                "Failed check: 'foo' =~ " . qr/bar/,
                'extra diag'
            ];
        };
        end_events;
    },
    "Got expected events for 'like'"
);

unlike('xxx', qr/yyy/, "testing unlike");

@lines = ();
events_are(
    intercept {
        unlike("foo", qr/bar/, 'pass'); push @lines => __LINE__;
        unlike("foo", qr/foo/, 'fail'); push @lines => __LINE__;
        unlike("foo", qr/foo/, 'fail', 'extra diag'); push @lines => __LINE__;
    },
    events {
        event Ok => sub { event_call pass => 1 };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[1]/s,
                "Failed check: 'foo' !~ " . qr/foo/,
            ];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[2]/s,
                "Failed check: 'foo' !~ " . qr/foo/,
                'extra diag'
            ];
        };
        end_events;
    },
    "Got expected events for 'unlike'"
);

cmp_ok( 'a', 'ne', 'b', "testing cmp_ok" );

@lines = ();
events_are(
    intercept {
        cmp_ok( 'a', 'ne', 'b', 'pass' ); push @lines => __LINE__;
        cmp_ok( 'a', 'ne', 'a', 'fail' ); push @lines => __LINE__;
        cmp_ok( 'a', 'eq', 'b', 'fail', 'extra diag' ); push @lines => __LINE__;
    },
    events {
        event Ok => sub { event_call pass => 1 };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[1]/s,
                "Failed check: 'a' ne 'a'",
            ];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'fail'.*line $lines[2]/s,
                "Failed check: 'a' eq 'b'",
                'extra diag'
            ];
        };
        end_events;
    },
    "Got expected events for cmp_ok",
);

events_are(
    intercept {
        BAIL_OUT 'oops';
        # Should not get here
        print STDERR "Something is wrong, did not bail out!\n";
        exit 255;
    },
    events {
        event Bail => { reason => 'oops' };
        end_events;
    },
    "Got bail event"
);

events_are(
    intercept {
        skip_all 'oops';
        # Should not get here
        print STDERR "Something is wrong, did not skip!\n";
        exit 255;
    },
    events {
        event Plan => { max => 0, directive => 'SKIP', reason => 'oops' };
        end_events;
    },
    "Got plan (skip_all) event"
);

events_are(
    intercept {
        plan(5);
    },
    events {
        event Plan => { max => 5 };
        end_events;
    },
    "Got plan"
);

events_are(
    intercept {
        ok(1);
        ok(2);
        done_testing;
    },
    events {
        event Ok => { pass => 1 };
        event Ok => { pass => 1 };
        event Plan => { max => 2 };
        end_events;
    },
    "Done Testing works"
);

events_are(
    intercept {
        ref_ok({}, 'HASH', 'pass');
        ref_ok([], 'ARRAY', 'pass');
        ref_ok({}, 'ARRAY', 'fail');
    },
    events {
        event Ok => { pass => 1 };
        event Ok => { pass => 1 };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test/,
                qr/'HASH\(.*\)' is not a 'ARRAY' reference/
            ],
        };
        end_events;
    },
    "ref_ok tests"
);

{
    package X;

    sub can {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }

    sub isa {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }

    sub does {
        my $thing = pop;
        return 1 if $thing =~ m/x/;
    }
}

events_are(
    intercept {
        isa_ok('X', qw/axe box fox/);
        can_ok('X', qw/axe box fox/);
        does_ok('X', qw/axe box fox/);

        isa_ok('X',  qw/foo bar axe box/);
        can_ok('X',  qw/foo bar axe box/);
        does_ok('X', qw/foo bar axe box/);
    },
    events {
        event Ok => { pass => 1, name => 'X->isa(...)' };
        event Ok => { pass => 1, name => 'X->can(...)' };
        event Ok => { pass => 1, name => 'X->does(...)' };

        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed/,
                "Failed: X->isa('foo')",
                "Failed: X->isa('bar')",
            ];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed/,
                "Failed: X->can('foo')",
                "Failed: X->can('bar')",
            ];
        };
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed/,
                "Failed: X->does('foo')",
                "Failed: X->does('bar')",
            ];
        };
        end_events;
    },
    "'can/isa/does_ok' events"
);

events_are(
    intercept {
        ok(0, "not todo");

        {
            my $todo = todo('todo 1');
            ok(0, 'todo fail');
        }

        ok(0, "not todo");

        my $todo = todo('todo 2');
        ok(0, 'todo fail');
        $todo = undef;

        ok(0, "not todo");

        todo 'todo 3' => sub {
            ok(0, 'todo fail');
        };

        ok(0, "not todo");
    },
    events {
        for my $id (1 .. 3) {
            event Ok => sub {
                event_call pass => 0;
                event_call effective_pass => 0;
                event_todo undef;
            };
            event Ok => sub {
                event_call pass => 0;
                event_call effective_pass => 1;
                event_todo "todo $id";
            };
        }
        event Ok => { pass => 0, effective_pass => 0 };
        end_events;
    },
    "Got todo events"
);

events_are(
    intercept {
        ok(1, 'pass');
        SKIP: {
            skip 'oops' => 5;

            ok(1, "Should not see this");
        }
    },
    events {
        event Ok => sub {
            event_call pass => 1;
            event_skip undef;
        };
        event Ok => sub {
            event_call pass => 1;
            event_skip 'oops';
        } for 1 .. 5;
        end_events;
    },
    "got skip events"
);

done_testing;
