use strict;
use warnings;

use Test::More;

use Test::Stream::State;
use Test::Stream::DebugInfo;
use Test::Stream::Event::Ok;
use Test::Stream::Event::Diag;
use Test::Stream::TAP qw/OUT_STD OUT_ERR OUT_TODO/;

my $dbg = Test::Stream::DebugInfo->new(
    frame => ['main_foo', 'foo.t', 42, 'main_foo::flubnarb'],
);

{ # Passing
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
    
    is_deeply(
        [$ok->to_tap(4)],
        [[OUT_STD, "ok 4 - the_test\n"]],
        "Got tap for basic ok"
    );
    
    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->is_passing, 1, "still passing");
}

{ # Failing
    local $ENV{HARNESS_ACTIVE} = 1;
    my $ok = Test::Stream::Event::Ok->new(
        debug => $dbg,
        pass  => 0,
        name  => 'the_test',
    );
    isa_ok($ok, 'Test::Stream::Event');
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 0, "effective pass");

    is_deeply(
        [$ok->subevents],
        $ok->diag,
        "Diag are sub events"
    );

    is_deeply(
        $ok->diag,
        [
            {
                debug => $dbg,
                linked => $ok,
                nested => undef,
                message => "\n  Failed test 'the_test'\n  at foo.t line 42.",
            }
        ],
        "Got diag"
    );
    
    is_deeply(
        [$ok->to_tap(4)],
        [
            [OUT_STD, "not ok 4 - the_test\n"],
            [OUT_ERR, "\n#   Failed test 'the_test'\n#   at foo.t line 42.\n"],
        ],
        "Got tap for failing ok"
    );
    
    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 1, "Added to failed count");
    is($state->is_passing, 0, "not passing");
}

{ # Failing w/ extra diag
    local $ENV{HARNESS_ACTIVE} = 1;
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

    is_deeply(
        $ok->diag,
        [
            {
                debug => $dbg,
                linked => $ok,
                nested => undef,
                message => "\n  Failed test 'the_test'\n  at foo.t line 42.",
            },
            {
                debug => $dbg,
                linked => $ok,
                nested => undef,
                message => "xxx",
            },
        ],
        "Got diag"
    );
    
    is_deeply(
        [$ok->to_tap(4)],
        [
            [OUT_STD, "not ok 4 - the_test\n"],
            [OUT_ERR, "\n#   Failed test 'the_test'\n#   at foo.t line 42.\n"],
            [OUT_ERR, "# xxx\n"],
        ],
        "Got tap for failing ok"
    );
    
    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 1, "Added to failed count");
    is($state->is_passing, 0, "not passing");
}

{ # Failing TODO
    local $ENV{HARNESS_ACTIVE} = 1;
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

    is_deeply(
        $ok->diag,
        [
            {
                debug => $dbg,
                linked => $ok,
                nested => undef,
                message => "\n  Failed (TODO) test 'the_test'\n  at foo.t line 42.",
            }
        ],
        "Got diag"
    );
    
    is_deeply(
        [$ok->to_tap(4)],
        [
            [OUT_STD, "not ok 4 - the_test # TODO A Todo\n"],
            [OUT_TODO, "\n#   Failed (TODO) test 'the_test'\n#   at foo.t line 42.\n"],
        ],
        "Got tap for failing ok"
    );
    
    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 0, "failed count unchanged");
    is($state->is_passing, 1, "still passing");

    $dbg->set_todo(undef);
}

{ # Skip
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

    is_deeply(
        [$ok->to_tap(4)],
        [
            [OUT_STD, "ok 4 - the_test # skip A Skip\n"],
        ],
        "Got tap for skip"
    );
    
    my $state = Test::Stream::State->new;
    $ok->update_state($state);
    is($state->count, 1, "Added to the count");
    is($state->failed, 0, "failed count unchanged");
    is($state->is_passing, 1, "still passing");

    $dbg->set_todo(undef);
}

done_testing;

