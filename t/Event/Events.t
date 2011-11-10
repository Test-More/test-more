#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl"; }
use Test::Builder2::Events;

my @events = map { "Test::Builder2::Event::".$_ }
                 qw(TestStart TestEnd
                    SetPlan
                    StreamMetadata
                    Log
                    Comment
                    SubtestStart
                    SubtestEnd
                 );

for my $class (@events) {
    ok $class->can("event_type"), "$class loaded";
}

ok "Test::Builder2::Result"->can("new_result"), "Test::Builder2::Result loaded";

done_testing;
