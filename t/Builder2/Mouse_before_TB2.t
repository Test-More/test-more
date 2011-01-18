#!/usr/bin/perl

# TB2 and Mouse have fought if loaded in the wrong order

BEGIN { require 't/test.pl'; }

my $Has_Mouse;
BEGIN {
    $Has_Mouse = eval {
        require Mouse;
        Mouse->import;
        1;
    };
}
skip_all "Mouse not installed" if !$Has_Mouse;

use Test::Builder2;

plan( tests => 1 );
pass('loads Test::Builder2 after loading Mouse');
