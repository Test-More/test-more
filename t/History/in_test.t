#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use Test::Builder2::Events;
use Test::Builder2::History;


note "test states"; {
    my $history = Test::Builder2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    ok !$history->in_test;
    ok !$history->done_testing;

    my $start = Test::Builder2::Event::TestStart->new;
    $ec->post_event( $start );
    ok $history->in_test;
    ok !$history->done_testing;

    my $end = Test::Builder2::Event::TestEnd->new;
    $ec->post_event( $end );
    ok !$history->in_test;
    ok $history->done_testing;

    is $history->test_start, $start;
    is $history->test_end, $end;
}

done_testing;
