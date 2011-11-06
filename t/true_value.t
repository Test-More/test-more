#!/usr/bin/perl

BEGIN { require 't/test.pl'; }

# For an unknown reason, this BEGIN block revealed some modules which did not
# return true values.  Even not knowing why, it is a useful test.
BEGIN {
    *CORE::GLOBAL::require = sub { CORE::require($_[0]) };
}

use strict;
use warnings;
use Test::More ();

pass("We loaded ok");

done_testing;
