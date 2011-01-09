#!/usr/bin/perl

# Test::Builder2::Module broke no_plan

use strict;
use warnings;

use Test::Simple 'no_plan';

ok("no_plan works with Test::Simple");
