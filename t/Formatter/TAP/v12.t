#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::EventCoordinator;
use TB2::Events;
use TB2::Streamer::Debug;

my $CLASS = 'TB2::Formatter::TAP::v12';
use_ok $CLASS;

note "v12 doesn't show the TAP version"; {
    my $streamer = TB2::Streamer::Debug->new;
    my $formatter = $CLASS->new(
        streamer => $streamer
    );

    my $ec = TB2::EventCoordinator->new(
        formatters => [$formatter]
    );

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 10 ) );

    is $streamer->read_all, "1..10\n";
}

done_testing;
