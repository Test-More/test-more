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


note "two test starts"; {
    my $history = Test::Builder2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = Test::Builder2::Event::TestStart->new;
    $ec->post_event( $start );

    my $another_start = Test::Builder2::Event::TestStart->new;
    ok !eval { $ec->post_event( $another_start ); 1; };

    ok $history->in_test;
    ok !$history->done_testing;

    is $history->test_start, $start, "the bogus start event doesn't overwrite the first";
}


note "two test ends"; {
    my $history = Test::Builder2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = Test::Builder2::Event::TestStart->new;
    my $end   = Test::Builder2::Event::TestEnd->new;
    $ec->post_event( $start );
    $ec->post_event( $end );

    my $another_end = Test::Builder2::Event::TestEnd->new;
    ok !eval { $ec->post_event( $another_end ); 1; };

    ok !$history->in_test;
    ok $history->done_testing;

    is $history->test_end, $end, "the bogus start event doesn't overwrite the first";
}


done_testing;
