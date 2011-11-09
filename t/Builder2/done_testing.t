#!/usr/bin/env perl

use strict;
use warnings;

use Test::Builder2;

my $tb = Test::Builder2->default;

$tb->ok(1);
$tb->ok(1);
$tb->done_testing(2);

