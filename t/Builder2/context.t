#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2;
use TB2::History;

my $tb = Test::Builder2->create;
$tb->test_state->clear_formatters;
$tb->test_state->ec->history(
    TB2::History->new( store_events => 1 )
);

my $from_idx = 0;
sub check_events {
    my($tb, $line) = @_;

    my $results = $tb->history->results;
    my $events  = $tb->history->events;

    my @have = @{$events}[ $from_idx .. $#{$events} ]; 

    for my $event ( @have ) {
        note sprintf "Type: %s ID: %s", $event->event_type, $event->object_id;
        is $event->file, __FILE__;
        is $event->line, $line;
    }

    $from_idx = $#{$events} + 1;
}


note "Test ok() and friends"; {
    my $line = __LINE__ + 1;
    $tb->ok(1);

    check_events($tb, $line);
}

note "Test done_testing() and friends"; {
    my $line = __LINE__ + 1;
    $tb->done_testing(1);

    check_events($tb, $line);
}

done_testing;
