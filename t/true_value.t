#!/usr/bin/perl

# For an unknown reason, this BEGIN block revealed some modules which did not return true
# values.  Even not knowing why, it's a useful test.
BEGIN {
    *CORE::GLOBAL::require = sub { CORE::require($_[0]) };
}

use strict;
use warnings;
use Test::More;

pass("We loaded ok");

done_testing;
