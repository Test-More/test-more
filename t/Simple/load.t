#!/usr/bin/perl

# Because I broke "use Test::Simple", here's a test

use strict;
use warnings;

BEGIN {
    # Avoid conflicting with Test::Simple::ok()
    package Test;
    require 't/test.pl';
}

use Test::Simple;

Test::plan tests => 1;
Test::pass("Test::Simple loaded with no arguments");
