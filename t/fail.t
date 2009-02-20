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

use Test::Builder;

# Set up a builder to record some failing tests.
my($out, $err);
{
    my $tb = Test::Builder->create;
    $tb->output(\$out);
    $tb->failure_output(\$err);

    $tb->plan( tests => 5 );

#line 28
    $tb->ok( 1, 'passing' );
    $tb->ok( 2, 'passing still' );
    $tb->ok( 3, 'still passing' );
    $tb->ok( 0, 'oh no!' );
    $tb->ok( 0, 'damnit' );
    $tb->_ending;
}

# Check that we got the right failure output.
{
    my $test = Test::Builder->new;

    $test->is_eq($out, <<OUT);
1..5
ok 1 - passing
ok 2 - passing still
ok 3 - still passing
not ok 4 - oh no!
not ok 5 - damnit
OUT

    $test->is_eq($err, <<ERR);
#   Failed test 'oh no!'
#   at $0 line 31.
#   Failed test 'damnit'
#   at $0 line 32.
# Looks like you failed 2 tests of 5.
ERR

    $test->done_testing(2);
}
