#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', 'lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;
use warnings;

use Test::Builder::NoOutput;

use Test::More tests => 10;

{
    my $tb = Test::Builder::NoOutput->create;

    $tb->plan( tests => 7 );
    for( 1 .. 3 ) {
        $tb->ok( $_, "We're on $_" );
        $tb->diag("We ran $_");
    }
    {
        my $indented = $tb->child;
        $indented->plan('no_plan');
        $indented->ok( 1, "We're on 1" );
        $indented->ok( 1, "We're on 2" );
        $indented->ok( 1, "We're on 3" );
        $indented->finalize;
    }
    for( 7, 8, 9 ) {
        $tb->ok( $_, "We're on $_" );
    }

    $tb->reset_outputs;
    is $tb->read, <<'END', 'Output should nest properly';
1..7
ok 1 - We're on 1
# We ran 1
ok 2 - We're on 2
# We ran 2
ok 3 - We're on 3
# We ran 3
    ok 1 - We're on 1
    ok 2 - We're on 2
    ok 3 - We're on 3
    1..3
ok 4 - Child of t/Nested/basic.t
ok 5 - We're on 7
ok 6 - We're on 8
ok 7 - We're on 9
END
}
{
    my $tb = Test::Builder::NoOutput->create;

    $tb->plan('no_plan');
    for( 1 .. 1 ) {
        $tb->ok( $_, "We're on $_" );
        $tb->diag("We ran $_");
    }
    {
        my $indented = $tb->child;
        $indented->plan('no_plan');
        $indented->ok( 1, "We're on 1" );
        {
            my $indented2 = $indented->child('with name');
            $indented2->plan( tests => 2 );
            $indented2->ok( 1, "We're on 2.1" );
            $indented2->ok( 1, "We're on 2.1" );
            $indented2->finalize;
        }
        $indented->ok( 1, 'after child' );
        $indented->finalize;
    }
    for(7) {
        $tb->ok( $_, "We're on $_" );
    }

    $tb->_ending;
    $tb->reset_outputs;
    is $tb->read, <<'END', 'We should allow arbitrary nesting';
ok 1 - We're on 1
# We ran 1
    ok 1 - We're on 1
        1..2
        ok 1 - We're on 2.1
        ok 2 - We're on 2.1
    ok 2 - with name
    ok 3 - after child
    1..3
ok 2 - Child of t/Nested/basic.t
ok 3 - We're on 7
1..3
END
}

{
    my $tb = Test::Builder::NoOutput->create;

    if(1) {
        my $child = $tb->child('expected to fail');
        $child->plan( tests => 3 );
        $child->ok(1);
        $child->ok(0);
        $child->ok(3);
        $child->finalize;
    }

    {
        my $child = $tb->child('expected to pass');
        $child->plan( tests => 3 );
        $child->ok(1);
        $child->ok(2);
        $child->ok(3);
        $child->finalize;
    }
    $tb->reset_outputs;
    is $tb->read, <<'END', 'Previous child failures should not force subsequent failures';
    1..3
    ok 1
    not ok 2
    
    #   Failed test at t/Nested/basic.t line 110.
    ok 3
    # Looks like you failed 1 test of 3.
not ok 1 - expected to fail

#   Failed test 'expected to fail'
#   at t/Nested/basic.t line 112.
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
    is "$child->{$_}", "$tb->{$_}", "The child should copy the ($_) filehandle"
        foreach qw{Out_FH Todo_FH Fail_FH};
    $child->finalize;
}
{
    ok defined &subtest, 'subtest() should be exported to our namespace';
    is prototype('subtest'), '$&', '... with the appropriate prototype';

    subtest 'subtest with plan', sub {
        plan tests => 2;
        ok 1, 'planned subtests should work';
        ok 1, '... and support more than one test';
    };
    subtest 'subtest without plan', sub {
        plan 'no_plan';
        ok 1, 'no_plan subtests should work';
        ok 1, '... and support more than one plan';
    };
}
