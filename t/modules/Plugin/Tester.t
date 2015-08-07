use strict;
use warnings;

use Test::Stream qw/-Tester/;

imported qw{
    grab intercept
    event
    ecall efield eprop
    events_are events
    end_events
    filter_events
};

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
            ecall pass => 1;
            efield effective_pass => 1;
            eprop line => $base;
        };
        event Ok => sub {
            ecall pass => 0;
            efield effective_pass => 0;
            eprop line => $base + 1;
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
            ecall pass => 1;
            efield effective_pass => 1;
            eprop line => $base;
        };
        event Ok => sub {
            ecall pass => 0;
            efield effective_pass => 0;
            eprop line => $base + 1;
        };
        end_events;
    },
    "Filtering"
);

events_are(
    $events,
    events {
        event Ok => sub {
            ecall pass => 1;
            efield effective_pass => 1;
            eprop line => $base;
            eprop file => __FILE__;
            eprop package => __PACKAGE__;
            eprop subname => 'Test::Stream::Plugin::More::ok';
            eprop trace => 'at ' . __FILE__ . ' line ' . $base;
            eprop skip => undef;
            eprop todo => undef;
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
            efield effective_pass => 1;
            eprop todo => 'foo';
            eprop skip => undef;
        };
        event Ok => sub {
            efield effective_pass => 1;
            eprop skip => 'blah';
            eprop todo => undef;
        };
        end_events;
    },
    "Todo and Skip"
);

my $FILE = __FILE__;
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
            ecall pass => 0;
            ecall diag => [
                qr/Failed test 'Inner check'/,
            ];
        };
        end_events;
    },
    "Self-Check"
);

done_testing;
