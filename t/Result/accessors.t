#!/usr/bin/perl -w

use strict;

BEGIN { require 't/test.pl' }

use_ok "Test::Builder2::Result";

my $result = Test::Builder2::Result->new_result(
    pass        => 1,
);
$result->diag([
    have => 23,
    want => 42
]);

isa_ok $result, "Test::Builder2::Result::Base";
is_deeply $result->diag, [have => 23, want => 42];

done_testing();
