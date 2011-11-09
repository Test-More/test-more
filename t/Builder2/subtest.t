#!/usr/bin/env perl -w

use strict;
use warnings;

use Test::Builder2;

my $tb = Test::Builder2->default;
$tb->ok(1, "first test");
$tb->ok(1, "second test");
$tb->subtest("a subtest" => sub {
    $tb->ok(1, "first subtest");
    $tb->ok(1, "second subtest");
    $tb->done_testing;
});
$tb->ok(1, "second test");

$tb->done_testing(4);
