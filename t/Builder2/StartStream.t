#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::StartStream;

note "Basic event"; {
    my $event = Test::Builder2::Event::StartStream->new;

    is $event->event_type, "start stream";
    is $event->as_hash->{event_type}, "start stream";
}

done_testing;
