#!/usr/bin/perl

use strict;

BEGIN { require 't/test.pl'; }

use Test::Builder;
use Test::Builder2;

my $tb1 = Test::Builder->new;
my $tb2 = Test::Builder2->default;

is $tb1->test_state, $tb2->test_state,
  "TB1 and TB2 have the same TestState";

done_testing;
