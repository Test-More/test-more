#!/usr/bin/perl -w

# TB2 and Mouse have fought if loaded in the wrong order

BEGIN { require 't/test.pl'; }

use Test::Builder2;

my $Has_Mouse;
BEGIN {
    $Has_Mouse = eval {
        require Mouse;
        Mouse->import;
        1;
    };
}
skip_all "Mouse not installed" if !$Has_Mouse;

plan( tests => 1 );
pass('loads Mouse after Test::Builder2');
