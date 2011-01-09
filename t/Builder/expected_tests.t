#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use lib 't/lib';
use Test::Builder::NoOutput;

note "Can call expected_tests() to set the plan"; {
    my $tb = Test::Builder::NoOutput->create;

    ok $tb->expected_tests(3);
    is $tb->expected_tests, 3;
    is $tb->read('out'), <<OUT, "outputs header";
TAP version 13
1..3
OUT

}

done_testing;
