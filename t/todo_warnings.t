#!/usr/bin/perl -w

# Test for 'Name "Foo::TODO" used only once: possible typo' warning.
# It shows up when a test function is called at BEGIN time in a
# package which is not the one Test::More was exported to.

use strict;
use warnings;

use Test::More;

BEGIN {
    package Foo;
    ::is( 23, 23 );
}

done_testing;
