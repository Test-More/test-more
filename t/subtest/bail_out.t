#!/usr/bin/perl -w

use strict;
use warnings;

{
    # Avoid conflicting with Test::More
    package MyTest;
    BEGIN { require "t/test.pl" }
}

use Test::Builder;
use Test::More;

my $output;
my $TB = Test::More->builder;
$TB->output(\$output);

MyTest::plan(tests => 2);

plan( tests => 4 );

ok 'foo';
subtest 'outer' => sub {
    plan tests => 3;
    ok 'sub_foo';
    subtest 'inner' => sub {
        plan tests => 3;
        ok 'sub_sub_foo';
        ok 'sub_sub_bar';
        BAIL_OUT("ROCKS FALL! EVERYONE DIES!");
        ok 'sub_sub_baz';
    };
    ok 'sub_baz';
};


END {
    MyTest::is( $output, <<'OUT' );
TAP version 13
1..4
ok 1
    TAP version 13
    1..3
    ok 1
        TAP version 13
        1..3
        ok 1
        ok 2
Bail out!  ROCKS FALL! EVERYONE DIES!
OUT

    MyTest::is( $?, 255, "bail out sets non-zero exit" );

    # Don't exit non-zero because of the bail out
    $? = 0;

    # I can't get this to fire after the END block, so suppress Test::Builder's ending.
    Test::More->builder->no_ending(1);
}
