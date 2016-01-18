use Test2::Bundle::Extended -target => 'Test2::Workflow';
BEGIN { require 't/tools.pl' }
use Test2::Tools::Spec;
no Test2::Tools::Spec;

use Test2::Workflow qw/workflow_run/;

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

like(
    $events,
    array {
        event Subtest => { pass => 1 }; # Nothing special

        # Failure in the inner block
        fail_events Subtest => sub {
            call pass => 0;
            call subevents => array {
                fail_events Subtest => sub {
                    call pass => 0;
                    call subevents => array {
                        fail_events Ok => { pass => 0 };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        fail_events Subtest => sub {
            call pass => 0;
            call subevents => array {
                fail_events Subtest => sub {
                    call pass => 0;
                    call subevents => array {
                        event Exception => { error => qr{xxx} };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        fail_events Subtest => sub {
            call pass => 0;
            call subevents => array {
                fail_events Subtest => sub {
                    call pass => 0;
                    call subevents => array {
                        fail_events Ok => { name => 'a', pass => 0 };
                        fail_events Ok => { name => 'b', pass => 0 };
                        fail_events Ok => {
                            name => 'wrapper',
                            pass => 0,
                        };
                        event Plan => {};
                        end;
                    };
                };
                event Plan => { max => 1 };
                end;
            };
        };

        fail_events Subtest => sub {
            call pass => 0;
            call subevents => array {
                fail_events Subtest => sub {
                    call pass => 0;
                    call subevents => array {
                        event Exception => { error => qr{xxx} };
                        fail_events Ok => { name => 'b', pass => 0 };
                        fail_events Ok => {
                            name => 'wrapper',
                            pass => 0,
                        };
                        event Plan => {};
                        end;
                    };
                };
                event Plan => { max => 1 };
                end;
            };
        };

        fail_events Subtest => sub {
            call pass => 0;
            call subevents => array {
                fail_events Subtest => sub {
                    call pass => 0;
                    call subevents => array {
                        fail_events Ok => {
                            pass => 0,
                            name => 'wrapper',
                        };
                        event Diag => { message => qr/Inner sub was never called in block 'wrapper'/ };
                        event Ok => { pass => 1 };
                        event Plan => {};
                        end;
                    };
                };
                event Plan => { max => 1 };
                end;
            };
        };

        # The final ok for the package
        fail_events Ok => { pass => 0, name => 'main' };
        end;
    },
    "Got expected events"
);

done_testing;
