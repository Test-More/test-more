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

my $output;
my $TB = Test::More->builder;
$TB->output(\$output);

my $Test = Test::Builder->create;
$Test->level(0);

$Test->plan(tests => 3);

plan tests => 4;

$ENV{TEST_MORE_BAIL_EARLY}=1;
ok(0, "Let's see what happens when we fail");

$Test->is_eq( $output, <<'OUT' );
1..4
not ok 1 - Let's see what happens when we fail
Bail out!  Early exit requested.
OUT

$Test->is_eq( $Exit_Code, 255 );

$Test->ok( $Test->can("BAILOUT"), "Backwards compat" );
