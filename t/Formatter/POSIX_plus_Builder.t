#!/usr/bin/perl -w

# Full test of using a non-TAP outputter.

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder2;
use TB2::Formatter::POSIX;

my $test = Test::Builder2->create;

my $posix = TB2::Formatter::POSIX->new(
  streamer_class => 'TB2::Streamer::Debug'
);

$test->test_state->formatters([$posix]);

$test->ok(1, "this is a pass");
is $posix->streamer->read('out'), <<"END";
Running $0
PASS: this is a pass
END

$test->ok(0, "this is a fail");
is $posix->streamer->read('out'), "FAIL: this is a fail\n";

done_testing(2);
