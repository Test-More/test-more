#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 104, coordinate_forks => 1;

if( fork ) {
    pass("Parent") for 1..100;
}
else {
    pass("Child before subtest");
    subtest "subtest in child" => sub {
        pass("Child subtest") for 1..100;
    };
    pass("Child after subtest");
    exit;
}

wait;

pass("Parent after wait");
