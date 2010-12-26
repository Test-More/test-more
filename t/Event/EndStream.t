#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::EndStream;

note "Basic event"; {
    my $event = Test::Builder2::Event::EndStream->new;

    is $event->event_type, "end stream";
    is $event->as_hash->{event_type}, "end stream";
}

done_testing;
