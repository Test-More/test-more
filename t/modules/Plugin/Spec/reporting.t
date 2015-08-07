use Test::Stream;
use Test::Stream::Tester;
use Test::Stream::Workflow qw/workflow_run/;
use Test::Stream::Spec;
no Test::Stream::Spec;

use Carp qw/croak confess/;

describe outer => sub {
    around_each wrapper => sub {
        $_[0]->();
    };

    tests inner => sub {
        ok(1);
    };
};

describe outer => sub {
    around_each wrapper => sub {
        $_[0]->();
    };

    tests inner => sub {
        ok(0);
    };
};

describe outer => sub {
    around_each wrapper => sub {
        $_[0]->();
    };

    tests inner => sub {
        die "xxx";
    };
};

describe outer => sub {
    around_each wrapper => sub {
        $_[0]->();
        ok(0, 'b');
    };

    tests inner => sub {
        ok(0, 'a');
    };
};

describe outer => sub {
    around_each wrapper => sub {
        $_[0]->();
        ok(0, 'b');
    };

    tests inner => sub {
        die "xxx";
    };
};

describe outer => sub {
    around_each wrapper => sub {
        # do not call $_[0]->();
    };

    tests inner => sub {
        ok(1);
    };
};

my $events = intercept { workflow_run };

events_are(
    $events,
    events {
        event Subtest => { pass => 1 }; # Nothing special

        # Failure in the inner block
        event Subtest => sub {
            event_call pass => 0;
            event_call diag => [ qr{Failed test 'outer'} ];
            event_call subevents => events {
                event Subtest => sub {
                    event_call pass => 0;
                    event_call diag => [ qr{Failed test 'inner'} ];
                    event_call subevents => events {
                        event Ok => { pass => 0 };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        event Subtest => sub {
            event_call pass => 0;
            event_call diag => [ qr{Failed test 'outer'}s ];
            event_call subevents => events {
                event Subtest => sub {
                    event_call pass => 0;
                    event_call diag => [ qr{Failed test 'inner'} ];
                    event_call subevents => events {
                        event Exception => { error => qr{xxx} };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        event Subtest => sub {
            event_call pass => 0;
            event_call diag => [ qr{Failed test 'outer'}s ];
            event_call subevents => events {
                event Subtest => sub {
                    event_call pass => 0;
                    event_call diag => [ qr{Failed test 'inner'} ];
                    event_call subevents => events {
                        event Ok => { name => 'a', pass => 0 };
                        event Ok => { name => 'b', pass => 0 };
                        event Ok => {
                            name => 'wrapper',
                            pass => 0,
                            diag => [ qr{Failed test \'wrapper\'} ],
                        };
                        event Plan => {};
                        end_events;
                    };
                };
                event Plan => { max => 1 };
                end_events;
            };
        };

        event Subtest => sub {
            event_call pass => 0;
            event_call diag => [ qr{Failed test 'outer'}s ];
            event_call subevents => events {
                event Subtest => sub {
                    event_call pass => 0;
                    event_call diag => [ qr{Failed test 'inner'} ];
                    event_call subevents => events {
                        event Exception => { error => qr{xxx} };
                        event Ok => { name => 'b', pass => 0 };
                        event Ok => {
                            name => 'wrapper',
                            pass => 0,
                            diag => [ qr{Failed test \'wrapper\'} ],
                        };
                        event Plan => {};
                        end_events;
                    };
                };
                event Plan => { max => 1 };
                end_events;
            };
        };

        event Subtest => sub {
            event_call pass => 0;
            event_call diag => [ qr{Failed test 'outer'}s ];
            event_call subevents => events {
                event Subtest => sub {
                    event_call pass => 0;
                    event_call diag => [ qr{Failed test 'inner'} ];
                    event_call subevents => events {
                        event Exception => { error => qr{Inner sub was never called} };
                        event Plan => {};
                        end_events;
                    };
                };
                event Plan => { max => 1 };
                end_events;
            };
        };

        # The final ok for the package
        event Ok => { pass => 0, name => 'main' };
        end_events;
    },
    "Got expected events"
);

done_testing;
