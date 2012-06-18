#!/usr/bin/perl -w

# Test that current_test will get the numbering right if no tests
# have yet been run by Test::Builder.

use strict;
use warnings;

use Test::Builder;
use TB2::History;

my $TB = Test::Builder->new;
my $history = TB2::History->new( store_events => 1 );
$TB->test_state->ec->history($history);

$TB->no_header(1);
print "ok 1\n";
print "ok 2\n";
$TB->current_test(2);

$TB->ok(1, "third test");

$TB->is_num( $TB->history->results->[0]->test_number, 1 );
$TB->is_num( $TB->history->results->[1]->test_number, 2 );

$TB->done_testing(5);
