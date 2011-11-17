#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use TB2::Events;
use TB2::History;


note "test states"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    ok !$history->in_test;
    ok !$history->done_testing;

    my $start = TB2::Event::TestStart->new;
    $ec->post_event( $start );
    ok $history->in_test;
    ok !$history->done_testing;

    my $end = TB2::Event::TestEnd->new;
    $ec->post_event( $end );
    ok !$history->in_test;
    ok $history->done_testing;

    is $history->test_start, $start;
    is $history->test_end, $end;
}


note "two test starts"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = TB2::Event::TestStart->new;
    $ec->post_event( $start );

    my $another_start = TB2::Event::TestStart->new;
    ok !eval { $ec->post_event( $another_start ); 1; };

    ok $history->in_test;
    ok !$history->done_testing;

    is $history->test_start, $start, "the bogus start event doesn't overwrite the first";
}


note "two test ends"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = TB2::Event::TestStart->new;
    my $end   = TB2::Event::TestEnd->new;
    $ec->post_event( $start );
    $ec->post_event( $end );

    my $another_end = TB2::Event::TestEnd->new;
    ok !eval { $ec->post_event( $another_end ); 1; };

    ok !$history->in_test;
    ok $history->done_testing;

    is $history->test_end, $end, "the bogus start event doesn't overwrite the first";
}


note "end before start"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $end   = TB2::Event::TestEnd->new;
    ok !eval { $ec->post_event( $end ); 1; };

    ok !$history->in_test;
    ok !$history->done_testing;
    ok !$history->test_end;
}


note "start after end"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = TB2::Event::TestStart->new;
    my $end   = TB2::Event::TestEnd->new;
    $ec->post_event($_) for $start, $end;

    my $another_start = TB2::Event::TestStart->new;
    ok !eval { $ec->post_event( $another_start ); 1; };

    ok !$history->in_test;
    ok $history->done_testing;
    is $history->test_end, $end;
    is $history->test_start, $start;
}


note "abort"; {
    my $history = TB2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    my $start = TB2::Event::TestStart->new;
    my $abort = TB2::Event::Abort->new;
    $ec->post_event($_) for $start, $abort;

    ok !$history->in_test;
    ok !$history->done_testing;
    is $history->abort, $abort;
}


done_testing;
