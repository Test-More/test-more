#!/usr/bin/perl -w

use strict;

BEGIN { require 't/test.pl' }

use_ok "TB2::Result";

my $result = TB2::Result->new_result(
    pass        => 1,
);
$result->diag([
    have => 23,
    want => 42
]);

isa_ok $result, "TB2::Result::Base";
is_deeply $result->diag, [have => 23, want => 42];

done_testing();
