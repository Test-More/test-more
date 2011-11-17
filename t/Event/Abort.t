#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = "TB2::Event::Abort";
use_ok $CLASS;

note "defaults"; {
    my $abort = $CLASS->new;

    is $abort->event_type, "abort";
    is $abort->reason, "";

    is_deeply $abort->as_hash, {
        event_type      => 'abort',
        event_id        => $abort->event_id,
        reason          => ''
    };
}


note "reason"; {
    my $abort = $CLASS->new(
        reason => "Warp core breech imminent"
    );

    is $abort->event_type, "abort";
    is $abort->reason, "Warp core breech imminent";
}

done_testing;
