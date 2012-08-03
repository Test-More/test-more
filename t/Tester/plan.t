#!/usr/bin/env perl

# This tests that TBT emulates a previous accidental behavior that some
# tests accidentally rely on.  The larger TBT plan would leak into the
# test tests.

use strict;
use warnings;

use Test::Builder::Tester tests => 1;
use Test::More;

test_out("ok 1 - TBT sets a plan in test tests");
test_out("ok 2");
ok( Test::Builder->new->has_plan, "TBT sets a plan in test tests" );
pass;
test_test();
