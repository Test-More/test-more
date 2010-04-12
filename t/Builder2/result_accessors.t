#!/usr/bin/perl -w

use strict;
use Test::More;

use_ok "Test::Builder2::Result";

my $result = Test::Builder2::Result->new_result(
    pass        => 1,
);
$result->diagnostic([
    have => 23,
    want => 42
]);

isa_ok $result, "Test::Builder2::Result::Base";
is_deeply $result->diagnostic, [have => 23, want => 42];

done_testing();
