#!perl -w

use strict;
use lib 't/lib';
use Test::Builder::NoOutput;

BEGIN { require 't/test.pl' }
plan tests => 3;

my $tb = Test::Builder::NoOutput->create;
$tb->plan(tests => 1);

$tb->_ending;
is($?, 255, "exit code");

is($tb->read('out'), <<OUT);
TAP version 13
1..1
OUT

is($tb->read('err'), <<ERR);
# No tests run!
ERR

exit $tb->history->test_was_successful ? 0 : 1;
