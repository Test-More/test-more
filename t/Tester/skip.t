#!/usr/bin/env perl -w

use strict;
use warnings;

use Test::Builder::Tester tests => 1;
use Test::More;

test_out("ok 1 # skip because");
SKIP: {
    skip "because", 1;
}
test_test("skip is using the legacy format");
