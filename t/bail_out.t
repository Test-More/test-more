#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}


BEGIN {
    # Put it in its own package to avoid interfering.
    package Test;
    require 't/test.pl'
}

use Test::Builder;

my $output;
my $tb = Test::Builder->create;
$tb->output(\$output);

Test::plan tests => 3;

Test::ok( $tb->can("BAILOUT"), "Backwards compat" );

{
    $tb->plan( tests => 2 );
    $tb->BAIL_OUT("ROCKS FALL! EVERYONE DIES!");
}

END {
    Test::is( $output, <<'OUT' );
TAP version 13
1..2
Bail out!  ROCKS FALL! EVERYONE DIES!
OUT

    Test::is $?, 255, "bail out exits with 255 for real";

    # Don't really exit with non-zero
    $? = 0;
}
