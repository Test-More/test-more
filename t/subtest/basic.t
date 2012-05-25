#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';
use Test::Builder::NoOutput;

use Test::More;

# Formatting may change if we're running under Test::Harness.
local $ENV{HARNESS_ACTIVE} = 0;

note "passing subtest"; {
#line 16
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->plan( tests => 7 );
    for( 1 .. 3 ) {
        $tb->ok( $_, "We're on $_" );
        $tb->diag("We ran $_");
    }

    $tb->subtest( first_subtest => sub {
        $tb->plan('no_plan');
        $tb->ok( 1, "We're on 1" );
        $tb->ok( 1, "We're on 2" );
        $tb->ok( 1, "We're on 3" );
    });

    for( 7, 8, 9 ) {
        $tb->ok( $_, "We're on $_" );
    }

    is $tb->read, <<"END", 'Output should nest properly';
TAP version 13
1..7
ok 1 - We're on 1
# We ran 1
ok 2 - We're on 2
# We ran 2
ok 3 - We're on 3
# We ran 3
    TAP version 13
    ok 1 - We're on 1
    ok 2 - We're on 2
    ok 3 - We're on 3
    1..3
ok 4 - first_subtest
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
END
}


note "subtest with no_plan"; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->plan('no_plan');
    for(1) {
        $tb->ok( $_, "We're on $_" );
        $tb->diag("We ran $_");
    }

    $tb->subtest( "first subtest", sub {
        $tb->plan('no_plan');
        $tb->ok( 1, "We're on 1" );
        $tb->subtest( "second subtest", sub {
            $tb->plan( tests => 2 );
            $tb->ok( 1, "We're on 2.1" );
            $tb->ok( 1, "We're on 2.2" );
        });
        $tb->ok( 1, 'after child' );
    });

    for(7) {
        $tb->ok( $_, "We're on $_" );
    }

    $tb->_ending;
    is $tb->read, <<"END", 'We should allow arbitrary nesting';
TAP version 13
ok 1 - We're on 1
# We ran 1
    TAP version 13
    ok 1 - We're on 1
        TAP version 13
        1..2
        ok 1 - We're on 2.1
        ok 2 - We're on 2.2
    ok 2 - second subtest
    ok 3 - after child
    1..3
ok 2 - first subtest
ok 3 - We're on 7
1..3
END
}

note "failing subtests"; {
#line 105
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->subtest('expected to fail' => sub {
        $tb->plan( tests => 3 );
        $tb->ok(1);
        $tb->ok(0);
        $tb->ok(3);
    });

    $tb->subtest('expected to pass' => sub {
        $tb->plan( tests => 3 );
        $tb->ok(1);
        $tb->ok(2);
        $tb->ok(3);
    });

    is $tb->read, <<"END", 'Previous child failures should not force subsequent failures';
TAP version 13
    TAP version 13
    1..3
    ok 1
    not ok 2
    #   Failed test at $0 line 111.
    ok 3
    # 1 test of 3 failed.
not ok 1 - expected to fail
#   Failed test 'expected to fail'
#   at $0 line 113.
    TAP version 13
    1..3
    ok 1
    ok 2
    ok 3
ok 2 - expected to pass
END
}


note "skip_all subtest"; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    is $tb->history->skip_count, 0;

    $tb->subtest("skippy says he loves you" => sub {
        $tb->plan( skip_all => 'cuz I said so' );
        $tb->ok(1, "this should not run");
        $tb->ok(0, "nor this");
    });

    is $tb->history->skip_count, 1, 'Subtests which "skip_all" are reported as skipped tests';
}


note "todo tests"; {
#line 162
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);
    $tb->plan( tests => 1 );

    $tb->subtest("with todo" => sub {
        $tb->plan( tests => 1 );
        $tb->todo_start( 'message' );
        $tb->ok(0);
        $tb->todo_end;
    });

    $tb->_ending;

    is $tb->read, <<"END", 'TODO tests should not make the parent test fail';
TAP version 13
1..1
    TAP version 13
    1..1
    not ok 1 # TODO message
    #   Failed (TODO) test at $0 line 169.
ok 1 - with todo
END
}

note "empty subtest"; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);
    $tb->plan( tests => 1 );

#line 189
    $tb->subtest("empty subtest" => sub {});

    $tb->_ending;
    is $tb->read, <<"END", 'Not running subtests should make the parent test fail';
TAP version 13
1..1
    TAP version 13
    1..0
    # No tests run!
not ok 1 - No tests run in subtest "empty subtest"
#   Failed test 'No tests run in subtest "empty subtest"'
#   at $0 line 189.
# 1 test of 1 failed.
END

}


done_testing;
