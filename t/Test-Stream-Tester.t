use strict;
use warnings;

use Test::Stream;

use Test::Stream::Tester;

can_ok(__PACKAGE__, qw{
    grab intercept
    event
    event_call event_field
    event_line event_file event_package event_sub event_trace
    event_todo event_skip
    events_are events
    end_events
    filter_events
});

my $base = __LINE__ + 2;
my $events = intercept {
    ok(1, 'pass');
    ok(0, 'fail');
    diag "foo";
    note "bar";
    done_testing;
};

events_are(
    $events,
    events {
        event Ok => sub {
            event_call pass => 1;
            event_field effective_pass => 1;
            event_line $base;
        };
        event Ok => sub {
            event_call pass => 0;
            event_field effective_pass => 0;
            event_line $base + 1;
        };
        event Diag => { message => 'foo' };
        event Note => { message => 'bar' };
        event Plan => { max => 2 };
        end_events;
    },
    "Basic check of events"
);

events_are(
    $events,
    events {
        filter_events { grep { $_->isa('Test::Stream::Event::Ok') } @_ };
        event Ok => sub {
            event_call pass => 1;
            event_field effective_pass => 1;
            event_line $base;
        };
        event Ok => sub {
            event_call pass => 0;
            event_field effective_pass => 0;
            event_line $base + 1;
        };
        end_events;
    },
    "Filtering"
);

events_are(
    $events,
    events {
        event Ok => sub {
            event_call pass => 1;
            event_field effective_pass => 1;
            event_line $base;
            event_file __FILE__;
            event_package __PACKAGE__;
            event_sub 'Test::Stream::ok';
            event_trace 'at ' . __FILE__ . ' line ' . $base;
            event_skip undef;
            event_todo undef;
        };
    },
    "METADATA"
);

events_are(
    intercept {
        todo foo => sub { ok(0, "todo fail") };
        SKIP: { skip 'blah' };
    },
    events {
        event Ok => sub {
            event_field effective_pass => 1;
            event_todo 'foo';
            event_skip undef;
        };
        event Ok => sub {
            event_field effective_pass => 1;
            event_skip 'blah';
            event_todo undef;
        };
        end_events;
    },
    "Todo and Skip"
);

events_are(
    intercept {
        events_are(
            $events,
            events {
                event Ok => { pass => 1 };
                event Ok => { pass => 1 }; # This is intentionally wrong.
            },
            "Inner check"
        );
    },
    events {
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'Inner check'/,
                q|Path: $_->[1]->{'pass'}
Failed Check: 0 == 1
t/Test-Stream-Tester.t
111 [
113   1: {
---     'pass': 0 == 1|,
            ];
        };
        end_events;
    },
    "Self-Check"
);

done_testing;
