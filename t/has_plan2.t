#! /usr/bin/perl -Tw

use strict;
use Test::Builder;
use Test::More 'no_plan';

is(Test::Builder->has_plan, 'no_plan', 'has no_plan');
