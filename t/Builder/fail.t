#!perl -w

# Simple test of what failure output looks like

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

# Normalize the output whether we're running under Test::Harness or not.
local $ENV{HARNESS_ACTIVE} = 0;

BEGIN { require 't/test.pl' }
use Test::Builder::NoOutput;

# Set up a builder to record some failing tests.
{
    my $tb = Test::Builder::NoOutput->create;
    $tb->plan( tests => 5 );

#line 28
    $tb->ok( 1, 'passing' );
    $tb->ok( 2, 'passing still' );
    $tb->ok( 3, 'still passing' );
    $tb->ok( 0, 'oh no!' );
    $tb->ok( 0, 'damnit' );
    $tb->_ending;

    is($tb->read('out'), <<OUT);
TAP version 13
1..5
ok 1 - passing
ok 2 - passing still
ok 3 - still passing
not ok 4 - oh no!
not ok 5 - damnit
OUT

    is($tb->read('err'), <<ERR);
#   Failed test 'oh no!'
#   at $0 line 31.
#   Failed test 'damnit'
#   at $0 line 32.
# 2 tests of 5 failed.
ERR

    done_testing(2);
}
