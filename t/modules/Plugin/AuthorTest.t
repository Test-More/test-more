use Test::Stream -V1, -SpecTester, LoadPlugin;

tests on => sub {
    local $ENV{AUTHOR_TESTING} = 1;
    is(
        intercept { load_plugin 'AuthorTest'; ok(1, "event") },
        array {
            event Ok => { pass => 1, name => 'event' };
            end;
        },
        "Ran tests"
    );
};

tests off => sub {
    local $ENV{AUTHOR_TESTING} = 0;
    is(
        intercept { load_plugin 'AuthorTest'; ok(1, "event") },
        array {
            event Plan => {
                max => 0,
                directive => 'SKIP',
                reason => 'Author test, set the AUTHOR_TESTING environment variable to run it',
            };
            end;
        },
        "skipped tests"
    );

};

describe alt_var => sub {
    tests on => sub {
        local $ENV{AUTHOR_FOO} = 1;
        is(
            intercept { load_plugin 'AuthorTest' => ['AUTHOR_FOO']; ok(1, "event") },
            array {
                event Ok => { pass => 1, name => 'event' };
                end;
            },
            "Ran tests"
        );
    };

    tests off => sub {
        local $ENV{AUTHOR_FOO} = 0;
        is(
            intercept { load_plugin 'AuthorTest' => ['AUTHOR_FOO']; ok(1, "event") },
            array {
                event Plan => {
                    max => 0,
                    directive => 'SKIP',
                    reason => 'Author test, set the AUTHOR_FOO environment variable to run it',
                };
                end;
            },
            "skipped tests"
        );
    };
};

done_testing;
