#!/usr/bin/perl -w

# What if there's a plan and done_testing but they don't match?

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

{
    # Normalize test output
    local $ENV{HARNESS_ACTIVE};

    $tb->plan( tests => 3 );
    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);

#line 24
    $tb->done_testing(2);
}


is($tb->read, <<"END");
TAP version 13
1..3
ok 1
ok 2
ok 3
not ok 4 - planned to run 3 but done_testing() expects 2
#   Failed test 'planned to run 3 but done_testing() expects 2'
#   at $0 line 24.
# 3 tests planned, but 4 ran.
# 1 test of 4 failed.
END

done_testing;
