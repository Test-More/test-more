use Test::Stream -V1, -SpecTester;

use Test::Stream::State;
use Test::Stream::DebugInfo;
use Test::Stream::Event::Ok;
use Test::Stream::Event::Diag;
use Test::Stream::Formatter::TAP qw/OUT_STD OUT_ERR OUT_TODO/;

# Make sure there is a fresh debug object for each group
my $dbg;
before_each dbg => sub {
    $dbg = Test::Stream::DebugInfo->new(
        frame => ['main_foo', 'foo.t', 42, 'main_foo::flubnarb'],
    );
};

tests Passing => sub {
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 1,
        name  => 'the_test',
    );
    ok(!$ok->causes_fail, "Passing 'OK' event does not cause failure");
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 1, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 1, "effective pass");
    is($ok->diag, undef, "no diag");

    warns {
        is(
            [$ok->to_tap(4)],
            [[OUT_STD, "ok 4 - the_test\n"]],
            "Got tap for basic ok"
        );
    };

    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->is_passing, 1, "still passing");
};

tests Failing => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 0,
        name  => 'the_test',
    );
    ok($ok->causes_fail, "A failing test causes failures");
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 0, "effective pass");

    warns {
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test\n"],
            ],
            "Got tap for failing ok"
        );
    };

    is(
        $ok->default_diag,
        "Failed test 'the_test'\nat foo.t line 42.",
        "default diag"
    );

    warns {
        $ok->set_diag([ $ok->default_diag ]);
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test\n"],
                [OUT_ERR, "# Failed test 'the_test'\n# at foo.t line 42.\n"],
            ],
            "Got tap for failing ok with diag"
        );

        $ENV{HARNESS_IS_VERBOSE} = 0;
        $ok->set_diag([ $ok->default_diag ]);
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test\n"],
                [OUT_ERR, "\n# Failed test 'the_test'\n# at foo.t line 42.\n"],
            ],
            "Got tap for failing ok with diag non verbose harness"
        );
    
        $ENV{HARNESS_ACTIVE} = 0;
        $ok->set_diag([ $ok->default_diag ]);
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test\n"],
                [OUT_ERR, "# Failed test 'the_test'\n# at foo.t line 42.\n"],
            ],
            "Got tap for failing ok with diag no harness"
        );
    };

    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 1, "Added to failed count");
    is($state->is_passing, 0, "not passing");
};

tests fail_with_diag => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 0,
        name  => 'the_test',
        diag  => ['xxx'],
    );
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 0, "effective pass");

    is(
        $ok->diag,
        [ "xxx" ],
        "Got diag"
    );

    warns {
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test\n"],
                [OUT_ERR, "# xxx\n"],
            ],
            "Got tap for failing ok"
        );
    };

    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 1, "Added to failed count");
    is($state->is_passing, 0, "not passing");
};

tests "Failing TODO" => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    $dbg->set_todo('A Todo');
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 0,
        name  => 'the_test',
    );
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 1, "effective pass is true from todo");

    $ok->set_diag([ $ok->default_diag ]);
    is(
        $ok->diag,
        [ "Failed (TODO) test 'the_test'\nat foo.t line 42." ],
        "Got diag"
    );

    warns {
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "not ok 4 - the_test # TODO A Todo\n"],
                [OUT_TODO, "# Failed (TODO) test 'the_test'\n# at foo.t line 42.\n"],
            ],
            "Got tap for failing ok"
        );
    };

    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 0, "failed count unchanged");
    is($state->is_passing, 1, "still passing");

    $dbg->set_todo(undef);
};

tests skip => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    $dbg->set_skip('A Skip');
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 1,
        name  => 'the_test',
    );
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 1, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 1, "effective pass");
    is($ok->diag, undef, "no diag");

    warns {
        is(
            [$ok->to_tap(4)],
            [
                [OUT_STD, "ok 4 - the_test # skip A Skip\n"],
            ],
            "Got tap for skip"
        );
    };

    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 0, "failed count unchanged");
    is($state->is_passing, 1, "still passing");

    $dbg->set_todo(undef);
};

tests init => sub {
    like(
        dies { Test::Stream::Event::Ok->new() },
        qr/No debug info provided!/,
        "Need to provide debug info"
    );

    like(
        dies { Test::Stream::Event::Ok->new(debug => $dbg, pass => 1, name => "foo#foo") },
        qr/'foo#foo' is not a valid name, names must not contain '#' or newlines/,
        "Some characters do not belong in a name"
    );

    like(
        dies { Test::Stream::Event::Ok->new(debug => $dbg, pass => 1, name => "foo\nfoo") },
        qr/'foo\nfoo' is not a valid name, names must not contain '#' or newlines/,
        "Some characters do not belong in a name"
    );

    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 1,
    );
    is($ok->effective_pass, 1, "set effective pass");

    $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 1,
        name => 'foo#foo',
        allow_bad_name => 1,
    );
    ok($ok, "allowed the bad name");
};

tests default_diag => sub {
    my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => 1);
    is([$ok->default_diag], [], "no diag for a pass");

    $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => 0);
    like([$ok->default_diag], [qr/Failed test at foo\.t line 42/], "got diag w/o name");

    $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => 0, name => 'foo');
    like([$ok->default_diag], [qr/Failed test 'foo'\nat foo\.t line 42/], "got diag w/name");
};

describe to_tap => sub {
    my $pass;
    case pass => sub { $pass = 1 };
    case fail => sub { $pass = 0 };

    around_all hide_warnings => sub {
        local $SIG{__WARN__} = sub { 1 };
        $_[0]->();
    };

    tests name_and_number => sub {
        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, name => 'foo');
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 - foo\n"],
            ],
            "Got expected output"
        );
    };

    tests no_number => sub {
        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, name => 'foo');
        my @tap = $ok->to_tap();
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " - foo\n"],
            ],
            "Got expected output"
        );
    };

    tests no_name => sub {
        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
            ],
            "Got expected output"
        );
    };

    tests skip_and_todo => sub {
        $dbg->set_todo('a');
        $dbg->set_skip('b');

        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO & SKIP a\n"],
            ],
            "Got expected output"
        );

        $dbg->set_todo("");

        @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO & SKIP\n"],
            ],
            "Got expected output"
        );
    };

    tests skip => sub {
        $dbg->set_skip('b');

        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # skip b\n"],
            ],
            "Got expected output"
        );

        $dbg->set_skip("");

        @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # skip\n"],
            ],
            "Got expected output"
        );
    };

    tests todo => sub {
        $dbg->set_todo('b');

        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO b\n"],
            ],
            "Got expected output"
        );

        $dbg->set_todo("");

        @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO\n"],
            ],
            "Got expected output"
        );
    };

    tests empty_diag_array => sub {
        my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, diag => []);
        my @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
            ],
            "Got expected output (No diag)"
        );

        $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
        @tap = $ok->to_tap(7);
        is(
            \@tap,
            [
                [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
            ],
            "Got expected output (No diag)"
        );
    };
};

done_testing;

