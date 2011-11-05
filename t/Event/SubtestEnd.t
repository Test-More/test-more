#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'Test::Builder2::Event::SubtestEnd';
use_ok $CLASS;

use Test::Builder2::History;

note "defaults"; {
    my $history = Test::Builder2::History->new;
    my $event = $CLASS->new(
        history => $history
    );
    isa_ok $event, $CLASS;

    is $event->history, $history;
    is $event->event_type, "subtest end";
    is_deeply $event->as_hash, {
        event_type      => "subtest end",
        event_id        => $event->event_id,
        history         => $history
    };
}


note "history is required"; {
    ok !eval { $CLASS->new() };
    ok !eval { $CLASS->new( history => bless {}, "Foo" ) };
}


done_testing;
