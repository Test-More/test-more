#!/usr/bin/perl -w

use strict;
use Test::More;

use_ok "Test::Builder2::Result";

my $result = Test::Builder2::Result->new(
    raw_passed  => 1
)->diagnostic([
    have => 23,
    want => 42
]);

isa_ok $result, "Test::Builder2::Result";
is_deeply $result->diagnostic, [have => 23, want => 42];

done_testing();
