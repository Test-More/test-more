#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::StreamEnd;

note "Basic event"; {
    my $event = Test::Builder2::Event::StreamEnd->new;

    is $event->event_type, "stream end";
    is $event->as_hash->{event_type}, "stream end";
}

done_testing;
