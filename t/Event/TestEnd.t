#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::TestEnd;

note "Basic event"; {
    my $event = Test::Builder2::Event::TestEnd->new;

    is $event->event_type, "test_end";
    is_deeply $event->as_hash, {
        event_type      => "test_end",
        event_id        => $event->event_id,
    };
}

done_testing;
