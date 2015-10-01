use Test::Stream -V1, -Tester, Subtest => [qw/subtest_streamed subtest_buffered/];

use File::Temp qw/tempfile/;

# A bug in older perls causes a strange error AFTER the program appears to be
# done if this test is run.
# "Size magic not implemented."
if ($] > 5.020000) {
    like(
        intercept {
            subtest_streamed 'foo' => sub {
                my ($fh, $name) = tempfile;
                print $fh <<"                EOT";
                    use Test::Stream -V1;
                    BEGIN { skip_all 'because' }
                    1;
                EOT
                close($fh);
                do $name;
                die $@ if $@;
                die "Ooops";
            };
        },
        array {
            event Note => { message => 'Subtest: foo' };
            event Subtest => sub {
                field pass => 1;
                field name => 'Subtest: foo';
                field subevents => array {
                    event Plan => { directive => 'SKIP', reason => 'because' };
                    end;
                };
            }
        },
        "skip_all in BEGIN inside a subtest works"
    );
}

like(
    intercept {
        subtest_streamed 'foo' => sub {
            subtest_buffered 'bar' => sub {
                ok(1, "pass");
            };
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            field pass => 1;
            field name => 'Subtest: foo';
            field subevents => array {
                event Subtest => sub {
                    field pass => 1;
                    field name => 'bar';
                    field subevents => array {
                        event Ok => sub {
                            field name => 'pass';
                            field pass => 1;
                        };
                    };
                };
            };
        };
    },
    "Can nest subtests"
);

my @lines = ();
like(
    intercept {
        push @lines => __LINE__ + 4;
        subtest_streamed 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'Subtest: foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
            };
        };
    },
    "Got events for passing subtest"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 4;
        subtest_streamed 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(0, "fail");
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 0;
            field name => 'Subtest: foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'fail';
                    field pass => 0;
                };
            };
        };
    },
    "Got events for failing subtest"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_streamed 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(1, "pass");
            done_testing;
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'Subtest: foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
                event Plan => { max => 1 };
                end;
            };
        };
    },
    "Can use done_testing"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_streamed 'foo' => sub {
            plan 1;
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'Subtest: foo';
            field subevents => array {
                event Plan => { max => 1 };
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
                end;
            };
        };
    },
    "Can plan"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_streamed 'foo' => sub {
            skip_all 'bleh';
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'Subtest: foo';
            field subevents => array {
                event Plan => { directive => 'SKIP', reason => 'bleh' };
                end;
            };
        };
    },
    "Can skip_all"
);

@lines = ();
like(
    intercept {
        subtest_streamed 'foo' => sub {
            BAIL_OUT 'cause';
            ok(1, "should not see this");
        };
    },
    array {
        event Note => { message => 'Subtest: foo' };
        event Bail => { reason => 'cause' };
        end;
    },
    "Can bail out"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 4;
        subtest_buffered 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
            };
        };
    },
    "Got events for passing subtest"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 4;
        subtest_buffered 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(0, "fail");
        };
    },
    array {
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 0;
            field name => 'foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'fail';
                    field pass => 0;
                };
            };
        };
    },
    "Got events for failing subtest"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_buffered 'foo' => sub {
            push @lines => __LINE__ + 1;
            ok(1, "pass");
            done_testing;
        };
    },
    array {
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'foo';
            field subevents => array {
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
                event Plan => { max => 1 };
                end;
            };
        };
    },
    "Can use done_testing"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_buffered 'foo' => sub {
            plan 1;
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'foo';
            field subevents => array {
                event Plan => { max => 1 };
                event Ok => sub {
                    prop file => __FILE__;
                    prop line => $lines[1];
                    field name => 'pass';
                    field pass => 1;
                };
                end;
            };
        };
    },
    "Can plan"
);

@lines = ();
like(
    intercept {
        push @lines => __LINE__ + 5;
        subtest_buffered 'foo' => sub {
            skip_all 'bleh';
            push @lines => __LINE__ + 1;
            ok(1, "pass");
        };
    },
    array {
        event Subtest => sub {
            prop file => __FILE__;
            prop line => $lines[0];
            field pass => 1;
            field name => 'foo';
            field subevents => array {
                event Plan => { directive => 'SKIP', reason => 'bleh' };
                end;
            };
        };
    },
    "Can skip_all"
);

@lines = ();
like(
    intercept {
        subtest_buffered 'foo' => sub {
            BAIL_OUT 'cause';
            ok(1, "should not see this");
        };
    },
    array {
        event Bail => { reason => 'cause' };
        end;
    },
    "Can bail out"
);

done_testing;
