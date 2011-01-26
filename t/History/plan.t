#!/usr/bin/perl

use strict;
use warnings;

use Test::Builder2::Events;
use Test::Builder2::EventCoordinator;

BEGIN { require "t/test.pl" }

note "History captures the plan"; {
    my $ec = Test::Builder2::EventCoordinator->create;
    $ec->clear_formatters;

    $ec->post_event( Test::Builder2::Event::StreamStart->new );

    my $plan = Test::Builder2::Event::SetPlan->new( asserts_expected => 2 );
    $ec->post_event( $plan );

    is $ec->history->plan, $plan, "history->plan";
    is $ec->history->plan->asserts_expected, 2;
}

done_testing;
