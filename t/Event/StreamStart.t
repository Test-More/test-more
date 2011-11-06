#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::StreamStart;

note "Basic event"; {
    my $event = Test::Builder2::Event::StreamStart->new;

    is $event->event_type, "test start";
    is $event->as_hash->{event_type}, "test start";
}

done_testing;
