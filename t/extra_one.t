#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::Builder::NoOutput;

BEGIN { require 't/test.pl' }

my $tb = Test::Builder::NoOutput->create;
$tb->plan( tests => 1 );
$tb->ok(1);
$tb->ok(2);
$tb->ok(3);
$tb->done_testing;

is($tb->read('out'), <<OUT);
TAP version 13
1..1
ok 1
ok 2
ok 3
OUT

is($tb->read('err'), <<ERR);
# 1 test planned, but 3 ran.
ERR

done_testing;

