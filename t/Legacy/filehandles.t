#!perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'Legacy/lib');
    }
    else {
        unshift @INC, 't/Legacy/lib';
    }
}

use Test::More tests => 1;
use Dev::Null;

tie *STDOUT, "Dev::Null" or die $!;

print "not ok 1\n";     # this should not print.
pass 'STDOUT can be mucked with';

