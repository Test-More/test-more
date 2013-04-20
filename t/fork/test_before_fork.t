#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 3, coordinate_forks => 1;

pass('one');
if (!fork) {
    pass('two');
    exit 0;
}
1 while wait == -1;
pass('three');
