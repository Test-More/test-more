#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::Event::TestEnd;

note "Basic event"; {
    my $event = TB2::Event::TestEnd->new;

    is $event->event_type, "test_end";
    is_deeply $event->as_hash, {
        event_type      => "test_end",
        object_id        => $event->object_id,
    };
}

done_testing;
