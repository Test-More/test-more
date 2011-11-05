#!perl -w

use strict;
use lib 't/lib';
use Test::More tests => 1;
use Dev::Null;

tie *STDOUT, "Dev::Null" or die $!;
print "not ok 1\n";     # this should not print.

tie *STDERR, "Dev::Null" or die $!;
print STDERR "This should not print";

pass 'STDOUT can be mucked with';
diag "this diagnostic should be seen";
