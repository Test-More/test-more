#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl"; }
use TB2::Events;

my @events = map { "TB2::Event::".$_ }
                 qw(TestStart TestEnd
                    SetPlan
                    TestMetadata
                    Log
                    Comment
                    SubtestStart
                    SubtestEnd
                    Abort
                 );

for my $class (@events) {
    ok $class->can("event_type"), "$class loaded";
}

ok "TB2::Result"->can("new_result"), "TB2::Result loaded";

done_testing;
