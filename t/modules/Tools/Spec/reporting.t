use Test2::Bundle::Extended -target => 'Test2::Workflow';
use Test2::Tools::Spec;

use Carp qw/croak confess/;

tests passing => sub {
    my $group = describe outer => sub {
        around_each wrapper => sub {
            $_[0]->();
        };

        tests inner => sub {
            ok(1);
        };
    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            event Subtest => { pass => 1 }; # Nothing special
        },
        "No extra diagnostics when passing"
    );
};

tests inner_failure => sub {
    my $group = describe outer => sub {
        describe outer => sub {
            around_each wrapper => sub {
                $_[0]->();
            };

            tests inner => sub {
                ok(0);
            };
        };

    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            fail_events Subtest => sub {
                call pass      => 0;
                call subevents => array {
                    fail_events Subtest => sub {
                        call pass      => 0;
                        call subevents => array {
                            fail_events Ok => {pass => 0};
                        };
                    };
                    event Plan => {max => 1};
                };
            };
        },
        "Failure in the inner block"
    );
};

tests inner_die => sub {
    my $group = describe outer => sub {
        around_each wrapper => sub {
            $_[0]->();
        };

        tests inner => sub {
            die "xxx";
        };
    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
        );
    };

    is(
        $events,
        array {
            fail_events Subtest => sub {
                call pass      => 0;
                call subevents => array {
                    fail_events Subtest => sub {
                        call pass      => 0;
                        call subevents => array {
                            event Exception => {error => match qr{xxx}};
                        };
                    };
                    event Plan => {max => 1};
                };
            };
        },
        "Exception in the inner block"
    );
};

tests 'extar wrapper diag' => sub {
    my $group = describe outer => sub {
        around_each wrapper => sub {
            $_[0]->();
            ok(0, 'b');
        };

        tests inner => sub {
            ok(0, 'a');
        };
    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            fail_events Subtest => sub {
                call name => 'inner';
                call subevents => array {
                    fail_events Ok => { name => 'a' };
                    fail_events Ok => { name => 'b' };
                    event Diag => { message => match qr/in block 'wrapper'/ };
                    event Plan => { max => 2 };
                    end;
                };
            };
        },
        "Helpful notice about the wrapper"
    );
};

tests 'wrapped die' => sub {
    my $group = describe outer => sub {
        around_each wrapper => sub {
            $_[0]->();
            ok(0, 'b');
        };

        tests inner => sub {
            die "xxx";
        };
    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            fail_events Subtest => sub {
                call name => 'inner';
                call subevents => array {
                    event Exception => { error => match qr/xxx/ };
                    fail_events Ok => { name => 'b', pass => 0 };
                    event Diag => { message => match qr/in block 'wrapper'/ };
                    event Plan => { max => 1 };
                    end;
                };
            };
        },
        "Wrapped block that throws exception."
    );
};

tests 'wrapper does not call inner' => sub {
    my $group = describe outer => sub {
        around_each wrapper => sub {
            # do not call $_[0]->();
        };

        tests inner => sub {
            use Carp qw/cluck/;
            cluck "xxx";
            ok(1, 'xxx');
        };
    };

    my $events = intercept {
        Test2::Workflow::Runner->instance->run(
            unit => $group,
            args => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            fail_events Subtest => sub {
                call name => 'inner';
                call subevents => array {
                    event Exception => { error => match qr/Inner sub was never called in block 'wrapper' defined in/ };
                    event Plan => { max => 0 };
                };
            };
            event Diag => { message => match qr/in block 'outer' defined in/ };
            end;
        },
        "Wrapper does not caller inner sub"
    );
};

done_testing;
