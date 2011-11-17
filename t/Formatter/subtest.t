#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }

use TB2::Formatter::PlusMinus;
use TB2::Events;
use TB2::EventCoordinator;

note "subtest formatter inherits the streamer"; {
    my $formatter = TB2::Formatter::PlusMinus->new(
        streamer_class  => "TB2::Streamer::Debug"
    );

    my $sub_formatter = $formatter->subtest_handler( TB2::Event::SubtestStart->new );
    is $formatter->streamer, $sub_formatter->streamer;
}

done_testing;
