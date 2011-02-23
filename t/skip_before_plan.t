#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

SKIP: {
    skip "skip one", 1;
}
pass("this is a pass");

done_testing(2);
