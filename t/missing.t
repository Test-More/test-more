#!/usr/bin/perl

use strict;
use lib 't/lib';

use Test::Builder::NoOutput;

BEGIN { require 't/test.pl' }

local $ENV{HARNESS_ACTIVE} = 0;


my $tb = Test::Builder::NoOutput->create;
$tb->plan(tests => 5);
$tb->level(0);

#line 30
$tb->ok(1, 'Foo');
$tb->ok(0, 'Bar');
$tb->ok(1, '1 2 3');
$tb->done_testing;


    is($tb->read('out'), <<OUT);
TAP version 13
1..5
ok 1 - Foo
not ok 2 - Bar
ok 3 - 1 2 3
OUT

    is($tb->read('err'), <<ERR);
#   Failed test 'Bar'
#   at $0 line 31.
#     You named your test '1 2 3'.  You shouldn't use numbers for your test names.
#     Very confusing.
# 5 tests planned, but 3 ran.
# 1 test of 3 failed.
ERR

done_testing;
