#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';
use Test::Builder::NoOutput;

use Test::More tests => 19;

# Formatting may change if we're running under Test::Harness.
local $ENV{HARNESS_ACTIVE} = 0;

note "passing subtest"; {
    my $tb = Test::Builder::NoOutput->create;

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

    $tb->reset_outputs;
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
    $tb->reset_outputs;
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
#line 104
    my $tb = Test::Builder::NoOutput->create;

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

    $tb->reset_outputs;
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
#   at $0 line 111.
    TAP version 13
    1..3
    ok 1
    ok 2
    ok 3
ok 2 - expected to pass
END
}


{
    my $tb    = Test::Builder::NoOutput->create;
    my $child = $tb->child('one');
    is $child->{$_}, $tb->{$_}, "The child should copy the ($_) filehandle"
        foreach qw{Out_FH Todo_FH Fail_FH};
    $child->finalize;
}
{
    my $tb    = Test::Builder::NoOutput->create;
    my $child = $tb->child('one');
    can_ok $child, 'parent';
    is $child->parent, $tb, '... and it should return the parent of the child';
    ok !defined $tb->parent, '... but top level builders should not have parents';

    can_ok $tb, 'name';
    is $tb->name, $0, 'The top level name should be $0';
    is $child->name, 'one', '... but child names should be whatever we set them to';
    $child->finalize;
    $child = $tb->child;
    is $child->name, 'Child of '.$tb->name, '... or at least have a sensible default';
    $child->finalize;
}
# Skip all subtests
{
    my $tb = Test::Builder::NoOutput->create;

    {
        my $child = $tb->child('skippy says he loves you');
        eval { $child->plan( skip_all => 'cuz I said so' ) };
        ok my $error = $@, 'A child which does a "skip_all" should throw an exception';
        isa_ok $error, 'Test::Builder::Exception', '... and the exception it throws';
    }
    subtest 'skip all', sub {
        plan skip_all => 'subtest with skip_all';
        ok 0, 'This should never be run';
    };
    my @details = Test::More->builder->details;
    is $details[-1]{type}, 'skip',
        'Subtests which "skip_all" are reported as skipped tests';
}

# to do tests
{
#line 204
    my $tb = Test::Builder::NoOutput->create;
    $tb->plan( tests => 1 );
    my $child = $tb->child;
    $child->plan( tests => 1 );
    $child->todo_start( 'message' );
    $child->ok( 0 );
    $child->todo_end;
    $child->finalize;
    $tb->_ending;
    $tb->reset_outputs;
    is $tb->read, <<"END", 'TODO tests should not make the parent test fail';
TAP version 13
1..1
    TAP version 13
    1..1
    not ok 1 # TODO message
    #   Failed (TODO) test at $0 line 209.
ok 1 - Child of $0
END
}
{
    my $tb = Test::Builder::NoOutput->create;
    $tb->plan( tests => 1 );
    my $child = $tb->child;
    $child->finalize;
    $tb->_ending;
    $tb->reset_outputs;
    my $expected = <<"END";
TAP version 13
1..1
not ok 1 - No tests run for subtest "Child of $0"
END
    like $tb->read, qr/\Q$expected/,
        'Not running subtests should make the parent test fail';
}
