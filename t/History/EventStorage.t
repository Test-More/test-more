#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;

my $CLASS = 'TB2::History::EventStorage';
require_ok $CLASS;

note "Event and result storage"; {
    my $storage = $CLASS->new;

    is_deeply $storage->events, [],     "empty events";
    is_deeply $storage->results, [],    "empty results";

    my @events  = map { TB2::Event::Comment->new( comment => "No $_" ) } 1..4;
    my @results = map { TB2::Result->new_result } 1..2;

    $storage->events_push( @events, @results );

    is_deeply $storage->events,  [@events, @results], "events_push to events";
    is_deeply $storage->results, [@results], "events_push split out results";
}

done_testing;
