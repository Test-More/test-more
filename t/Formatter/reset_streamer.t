#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Streamer::Debug;

# Simple formatter for testing
use TB2::Formatter::PlusMinus;

note "reset_streamer"; {
    my $formatter = TB2::Formatter::PlusMinus->new;

    my $streamer = $formatter->streamer;

    # Change the streamer
    $formatter->streamer( TB2::Streamer::Debug->new );
    isa_ok $formatter->streamer, 'TB2::Streamer::Debug';

    # Reset the streamer
    $formatter->reset_streamer;
    isa_ok $formatter->streamer, ref $streamer;
}


done_testing;
