#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::Event::SubtestEnd';
use_ok $CLASS;

use TB2::History;

note "defaults"; {
    my $history = TB2::History->new;
    my $event = $CLASS->new(
        history => $history
    );
    isa_ok $event, $CLASS;

    is $event->history, $history;
    is $event->event_type, "subtest_end";
    is_deeply $event->as_hash, {
        event_type      => "subtest_end",
        event_id        => $event->event_id,
        history         => $history
    };
}

done_testing;
