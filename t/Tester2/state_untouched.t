#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Simple ();
use TB2::Tester;

note "test state left untouched"; {
    my $ec = Test::Simple->builder->test_state;
    is_deeply $ec->history->event_count,  0,        "no events in the EC";
    is_deeply $ec->history->result_count, 0,        "no results in the EC";

    my $have = capture {
        Test::Simple::ok( 1 );
    };

    is_deeply $ec->history->event_count,  0,       "still no events";
    is_deeply $ec->history->result_count, 0,       "still no results";
}

done_testing;
