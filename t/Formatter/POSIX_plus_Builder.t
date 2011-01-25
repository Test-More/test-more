#!/usr/bin/perl -w

# Full test of using a non-TAP outputter.

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder2;
use Test::Builder2::Formatter::POSIX;

my $test = Test::Builder2->create;

my $posix = Test::Builder2::Formatter::POSIX->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);

$test->event_coordinator->formatters([$posix]);

$test->stream_start;
is $posix->streamer->read('output'), <<"END";
Running $0
END

$test->ok(1, "this is a pass");
is $posix->streamer->read('output'), <<"END";
PASS: this is a pass
END

$test->ok(0, "this is a fail");
is $posix->streamer->read('output'), "FAIL: this is a fail\n";

done_testing(3);
