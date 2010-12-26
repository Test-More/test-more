#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl"; }
use Test::Builder2::Events;

my @events = map { "Test::Builder2::Event::".$_ }
                 qw(StartStream EndStream SetPlan StreamMetadata);

for my $class (@events) {
    ok $class->can("event_type"), "$class loaded";
}

ok "Test::Builder2::Result"->can("new_result"), "Test::Builder2::Result loaded";
