#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';
BEGIN { require "t/test.pl" }

use Test::Builder2::Events;
use Test::Builder2::EventHandler;
use MyEventCollector;

note "default subtest_handler"; {
    my $watcher = MyEventCollector->new;
    my $sub_watcher = $watcher->subtest_handler( Test::Builder2::Event::SubtestStart->new );

    isa_ok $sub_watcher, "MyEventCollector";
    isnt $watcher, $sub_watcher;
}

done_testing;
