#!/usr/bin/perl -w

# What if done_testing is used without a plan?

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

{
    # Normalize test output
    local $ENV{HARNESS_ACTIVE};
    $tb->done_testing;
}


is($tb->read, <<"END");
TAP version 13
1..0
# No tests run!
END

done_testing;
