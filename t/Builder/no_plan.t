#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use lib 't/lib';
use Test::Builder::NoOutput;

note "Can call no_plan() to set the plan"; {
    my $tb = Test::Builder::NoOutput->create;

    ok $tb->no_plan;
    is $tb->read('out'), "TAP version 13\n", "outputs TAP version";
}

done_testing;
