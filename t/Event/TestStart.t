#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::Event::TestStart;

note "Basic event"; {
    my $event = TB2::Event::TestStart->new;

    is $event->event_type, "test_start";
    is_deeply $event->as_hash, {
        event_type      => "test_start",
        event_id        => $event->event_id,
    };
}

done_testing;
