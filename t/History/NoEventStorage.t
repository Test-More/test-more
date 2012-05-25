#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;

my $CLASS = 'TB2::History::NoEventStorage';
require_ok $CLASS;

note "Event and result storage"; {
    my $storage = $CLASS->new;

    isa_ok $storage, $CLASS;
    isa_ok $storage, "TB2::History::EventStorage";

    ok !eval { is_deeply $storage->events;  1 };
    ok !eval { is_deeply $storage->results; 1 };

    $storage->events_push( TB2::Event::Comment->new( comment => "No 1" ) );

    ok !eval { is_deeply $storage->events;  1 };
    ok !eval { is_deeply $storage->results; 1 };
}

done_testing;
