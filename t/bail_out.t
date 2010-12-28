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

my $Exit_Code;
BEGIN {
    *CORE::GLOBAL::exit = sub { $Exit_Code = shift; };
}

BEGIN {
    package Test;
    require 't/test.pl'
}

use Test::More;

my $output;
my $TB = Test::More->builder;
$TB->output(\$output);

{
    plan tests => 4;
    BAIL_OUT("ROCKS FALL! EVERYONE DIES!");

    Test::is( $output, <<'OUT' );
TAP version 13
1..4
Bail out!  ROCKS FALL! EVERYONE DIES!
OUT

    Test::is( $Exit_Code, 255 );
}

Test::ok( $TB->can("BAILOUT"), "Backwards compat" );

Test::done_testing;
