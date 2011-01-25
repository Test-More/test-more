#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Simple ();
use Test::Builder2::Tester;

note "event coordinator left untouched"; {
    my $ec = Test::Simple->Builder->event_coordinator;
    is_deeply $ec->history->events,  [],        "no events in the EC";
    is_deeply $ec->history->results, [],        "no results in the EC";

    my $have = capture {
        Test::Simple::ok( 1 );
    };

    is_deeply $ec->history->events,  [],        "still no events";
    is_deeply $ec->history->results, [],        "still no results";
}

note "capturing nothing"; {
    my $have = capture {};

    is_deeply $have->results, [];
    is_deeply $have->events, [];
}

note "capturing results"; {
    my $have = capture {
        Test::Simple::ok( 1, "a pass" );
        Test::Simple::ok( 0, "a fail" );
    };

    is @{ $have->results }, 2;
}

done_testing;
