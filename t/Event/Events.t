#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl"; }
use TB2::Events;

my @events = TB2::Events->event_classes;

for my $class (grep !/TB2::Result/, @events) {
    ok $class->can("event_type"), "$class loaded";
}

ok "TB2::Result"->can("new_result"), "TB2::Result loaded";

done_testing;
