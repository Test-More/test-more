# $Id$
BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}   

use strict;

use Test::Builder;
my $TB = Test::Builder->create;
$TB->plan( tests => 2 );

package main;
require Test::More;

require Test::Simple::Catch;
my($out, $err) = Test::Simple::Catch::caught();

Test::More->import('skip_all');


END {
    $TB->is_eq($$out, "1..0\n");
    $TB->is_eq($$err, "");
}
