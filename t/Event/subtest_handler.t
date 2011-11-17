#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';
BEGIN { require "t/test.pl" }

use TB2::Events;
use TB2::EventHandler;
use MyEventCollector;

note "default subtest_handler"; {
    my $handler = MyEventCollector->new;
    my $sub_handler = $handler->subtest_handler( TB2::Event::SubtestStart->new );

    isa_ok $sub_handler, "MyEventCollector";
    isnt $handler, $sub_handler;
}

done_testing;
