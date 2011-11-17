#!/usr/bin/perl

use strict;
use warnings;

use TB2::Events;
use TB2::EventCoordinator;

BEGIN { require "t/test.pl" }

note "History captures the plan"; {
    my $ec = TB2::EventCoordinator->new;
    $ec->clear_formatters;

    $ec->post_event( TB2::Event::TestStart->new );

    my $plan = TB2::Event::SetPlan->new( asserts_expected => 2 );
    $ec->post_event( $plan );

    is $ec->history->plan, $plan, "history->plan";
    is $ec->history->plan->asserts_expected, 2;
}

done_testing;
