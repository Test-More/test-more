#!/usr/bin/perl

use strict;

BEGIN { require 't/test.pl'; }

use Test::Builder;
use Test::Builder2;

my $tb1 = Test::Builder->new;
my $tb2 = Test::Builder2->singleton;

is $tb1->event_coordinator, $tb2->event_coordinator,
  "TB1 and TB2 have the same EventCoordinator";

done_testing;
