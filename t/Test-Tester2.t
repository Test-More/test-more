use strict;
use warnings;

use Test::More 'modern';

use ok 'Test::Tester2';

can_ok( __PACKAGE__, 'intercept', 'events_are' );

my $events = intercept {
    ok(1, "Woo!");
    ok(0, "Boo!");
};

isa_ok($events->[0], 'Test::Stream::Event::Ok');
is($events->[0]->bool, 1, "Got one success");
is($events->[0]->name, "Woo!", "Got test name");

isa_ok($events->[1], 'Test::Stream::Event::Ok');
is($events->[1]->bool, 0, "Got one fail");
is($events->[1]->name, "Boo!", "Got test name");

$events = undef;
my $grab = grab();
my $got = $grab ? 1 : 0;
ok(1, "Intercepted!");
ok(0, "Also Intercepted!");
$events = $grab->finish;
ok($got, "Delayed test that we did in fact get a grab object");
is($grab, undef, "Poof! vanished!");
is(@$events, 2, "got 2 events (2 ok)");
events_are(
    $events,
    check {
        event ok => { bool => 1 };
        event ok => {
            bool => 0,
            diag => check {
                event diag => { };
            },
        };
        dir end => 'intercepted via grab 1';
    }
);

$events = undef;
$grab = grab();
ok(1, "Intercepted!");
ok(0, "Also Intercepted!");
events_are(
    $grab,
    check {
        event ok => { bool => 1 };
        event ok => { bool => 0, diag => check { event diag => {} } };
        dir end => 'intercepted via grab 2';
    }
);
ok(!$grab, "Maybe it never existed?");

$events = intercept {
    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$events, 2, "Only got 2");
isa_ok($events->[0], 'Test::Stream::Event::Ok');
isa_ok($events->[1], 'Test::Stream::Event::Bail');

$events = intercept {
    plan skip_all => 'All tests are skipped';

    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$events, 1, "Only got 1");
isa_ok($events->[0], 'Test::Stream::Event::Plan');

my $file = __FILE__;
my $line = __LINE__ + 4;
events_are(
    intercept {
        events_are(
            intercept { ok(1, "foo") },
            ok => {id => 'blah', bool => 0},
            end => 'Lets name this test!',
        );
    },

    ok => {
        id => 'first', bool => 0,
        diag => [
            diag => {message => qr{Failed test 'Lets name this test!'.*at (\./)?$0 line}s},
            diag => {message => q{(ok blah) Wanted bool => '0', but got bool => '1'}},
            diag => {message => <<"            EOT"},
Got Event: ok => {
  name: foo
  bool: 1
  real_bool: 1
  in_todo: 0
  package: main
  file: $file
  line: $line
  pid: $$
  encoding: legacy
  tool_name: ok
  tool_package: Test::More
  tap: ok - foo
  diag: [0]
  in_subtest: 0
  level: 1
}
Expected: ok => {
  bool: 0
}
            EOT
        ],
    },

    end => 'Failure diag checking',
);

events_are(
    intercept {
        events_are(
            intercept { ok(1, "foo"); ok(1, "bar") },
            ok => {id => 'blah', bool => 1},
            'end'
        );
    },

    ok => {
        id => 'first', bool => 0,
        diag => [
            diag => {},
            diag => {message => q{Expected end of events, but more events remain}},
            diag => {},

            'end',
        ],
    },

    end => 'skipping a diag',
);

DOCS_1: {
    # Intercept all the Test::Stream::Event objects produced in the block.
    my $events = intercept {
        ok(1, "pass");
        ok(0, "fail");
        diag("xxx");
    };

    # By Hand
    is($events->[0]->bool, 1, "First event passed");

    # With help
    events_are(
        $events,
        ok   => { id => 'a', bool => 1, name => 'pass' },
        ok   => {
            id => 'b', bool => 0, name => 'fail',
            diag => [
                diag => { message => qr/Failed test 'fail'/ },
            ],
        },
        diag => { message => qr/xxx/ },
        end => 'docs 1',
    );
}

DOCS_2: {
    require Test::Simple;
    my $events = intercept {
        Test::More::ok(1, "foo");
        Test::More::ok(1, "bar");
        Test::More::ok(1, "baz");
        Test::Simple::ok(1, "bat");
    };

    events_are(
        $events,
        ok => { name => "foo" },
        ok => { name => "bar" },

        # From this point on, only more 'Test::Simple' events will be checked.
        filter_provider => 'Test::Simple',

        # So it goes right to the Test::Simple event.
        ok => { name => "bat" },

        end => 'docs 2',
    );
}

DOCS_3: {
    my $events = intercept {
        ok(1, "foo");
        diag("XXX");

        ok(1, "bar");
        diag("YYY");

        ok(1, "baz");
        diag("ZZZ");
    };

    events_are(
        $events,
        ok => { name => "foo" },
        diag => { message => 'XXX' },
        ok => { name => "bar" },
        diag => { message => 'YYY' },

        # From this point on, only 'diag' types will be seen
        filter_type => 'diag',

        # So it goes right to the next diag.
        diag => { message => 'ZZZ' },

        end => 'docs 3',
    );
}

DOCS_4: {
    my $events = intercept {
        ok(1, "foo");
        diag("XXX");

        ok(1, "bar");
        diag("YYY");

        ok(1, "baz");
        diag("ZZZ");
    };

    events_are(
        $events,
        ok => { name => "foo" },

        skip => 1, # Skips the diag

        ok => { name => "bar" },

        skip => 2, # Skips a diag and an ok

        diag => { message => 'ZZZ' },

        end => 'docs 4'
    );
}

DOCS_5: {
    my $events = intercept {
        ok(1, "foo");

        diag("XXX");
        diag("YYY");
        diag("ZZZ");

        ok(1, "bar");
    };

    events_are(
        $events,
        ok => { name => "foo" },

        skip => '*', # Skip until the next 'ok' is found since that is our next check.

        ok => { name => "bar" },

        end => 'docs 5',
    );
}

DOCS_6: {
    my $events = intercept {
        ok(1, "foo");

        diag("XXX");
        diag("YYY");

        ok(1, "bar");
        diag("ZZZ");

        ok(1, "baz");
    };

    events_are(
        intercept {
            events_are(
                $events,

                name => 'docs 6 inner',

                seek => 1,
                ok => { name => "foo" },
                # The diags are ignored,
                ok => { name => "bar" },

                seek => 0,

                # This will fail because the diag is not ignored anymore.
                ok => { name => "baz" },
            );
        },

        ok => {
            bool => 0,
            diag => [
                diag => { message => qr/Failed test 'docs 6 inner'/ },
                diag => { message => q{(ok 3) Wanted event type 'ok', But got: 'diag'} },
                diag => { message => qr/Full event found was:/ },
            ],
        },

        end => 'docs 6',
    );
}

done_testing;
