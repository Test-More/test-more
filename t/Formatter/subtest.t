#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }

use Test::Builder2::Formatter::PlusMinus;
use Test::Builder2::Events;
use Test::Builder2::EventCoordinator;

note "subtest formatter inherits the streamer"; {
    my $formatter = Test::Builder2::Formatter::PlusMinus->new(
        streamer_class  => "Test::Builder2::Streamer::Debug"
    );

    my $sub_formatter = $formatter->subtest_handler( Test::Builder2::Event::SubtestStart->new );
    is $formatter->streamer, $sub_formatter->streamer;
}

done_testing;
