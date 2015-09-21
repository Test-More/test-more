use Test::Stream(
    qw/-V1 -Tester Spec/,
);
no Test::Stream::Plugin::Spec;

use Test::Stream::Workflow qw/workflow_run/;

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
        event Subtest => sub {
            call pass => 0;
            call diag => [ qr{Failed test 'outer'} ];
            call subevents => array {
                event Subtest => sub {
                    call pass => 0;
                    call diag => [ qr{Failed test 'inner'} ];
                    call subevents => array {
                        event Ok => { pass => 0 };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        event Subtest => sub {
            call pass => 0;
            call diag => [ qr{Failed test 'outer'}s ];
            call subevents => array {
                event Subtest => sub {
                    call pass => 0;
                    call diag => [ qr{Failed test 'inner'} ];
                    call subevents => array {
                        event Exception => { error => qr{xxx} };
                    };
                };
                event Plan => { max => 1 };
            };
        };

        event Subtest => sub {
            call pass => 0;
            call diag => [ qr{Failed test 'outer'}s ];
            call subevents => array {
                event Subtest => sub {
                    call pass => 0;
                    call diag => [ qr{Failed test 'inner'} ];
                    call subevents => array {
                        event Ok => { name => 'a', pass => 0 };
                        event Ok => { name => 'b', pass => 0 };
                        event Ok => {
                            name => 'wrapper',
                            pass => 0,
                            diag => [ qr{Failed test \'wrapper\'} ],
                        };
                        event Plan => {};
                        end;
                    };
                };
                event Plan => { max => 1 };
                end;
            };
        };

        event Subtest => sub {
            call pass => 0;
            call diag => [ qr{Failed test 'outer'}s ];
            call subevents => array {
                event Subtest => sub {
                    call pass => 0;
                    call diag => [ qr{Failed test 'inner'} ];
                    call subevents => array {
                        event Exception => { error => qr{xxx} };
                        event Ok => { name => 'b', pass => 0 };
                        event Ok => {
                            name => 'wrapper',
                            pass => 0,
                            diag => [ qr{Failed test \'wrapper\'} ],
                        };
                        event Plan => {};
                        end;
                    };
                };
                event Plan => { max => 1 };
                end;
            };
        };

        event Subtest => sub {
            call pass => 0;
            call diag => [ qr{Failed test 'outer'}s ];
            call subevents => array {
                event Subtest => sub {
                    call pass => 0;
                    call diag => [ qr{Failed test 'inner'} ];
                    call subevents => array {
                        event Ok => {
                            pass => 0,
                            name => 'wrapper',
                            diag => [qr/Failed/, qr/Inner sub was never called in block 'wrapper'/],
                        };
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
        event Ok => { pass => 0, name => 'main' };
        end;
    },
    "Got expected events"
);

done_testing;
