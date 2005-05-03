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


use Test::Builder;
use Test::More;
use TieOut;

my $output = tie *FAKEOUT, 'TieOut';
my $TB = Test::More->builder;
$TB->output(\*FAKEOUT);

my $Test = Test::Builder->create;
$Test->plan(tests => 2);
$Test->level(0);

plan tests => 4;

BAIL_OUT("ROCKS FALL! EVERYONE DIES!");


$Test->is_eq( $output->read, <<'OUT' );
1..4
Bail out!  ROCKS FALL! EVERYONE DIES!
OUT

$Test->is_eq( $Exit_Code, 255 );
