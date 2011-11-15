#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder2::Formatter::TAP;
use Test::Builder2::EventCoordinator;
use Test::Builder2::Events;


my $formatter;
sub setup {
    $formatter = Test::Builder2::Formatter::TAP->new(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "Test::Builder2::Formatter::TAP";

    my $ec = Test::Builder2::EventCoordinator->new(
        formatters => [$formatter],
    );

    return $ec;
}

sub last_output {
    $formatter->streamer->read('out');
}

sub last_error {
    $formatter->streamer->read('err');
}


note "abort, no reason"; {
    my $ec = setup;

    $ec->post_event( Test::Builder2::Event::Abort->new );

    is last_output, "Bail out!\n";
    is last_error,  "";
}


note "abort, with reason"; {
    my $ec = setup;

    $ec->post_event(
        Test::Builder2::Event::Abort->new( reason => "Warp core breech imminent" )
    );

    is last_output, "Bail out!  Warp core breech imminent\n";
    is last_error,  "";
}


note "abort, multi-line reason"; {
    my $ec = setup;

    $ec->post_event(
        Test::Builder2::Event::Abort->new(
            reason => <<REASON
You
done
got
smote
REASON
        )
    );

    is last_output, "Bail out!  You\\ndone\\ngot\\nsmote\\n\n";
    is last_error,  "";
}


done_testing;
