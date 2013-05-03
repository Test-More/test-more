#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::Event::Generic';
require_ok $CLASS;

note "generic events"; {
    my $line = __LINE__ + 1;
    my $event = $CLASS->new(
        foo => 23,
        bar => 42,
        event_type => "some_thing",
    );

    is $event->foo, 23;
    is $event->bar, 42;
    is $event->event_type, "some_thing";
    ok $event->object_id;

    is_deeply $event->as_hash, {
        foo             => 23,
        bar             => 42,
        event_type      => 'some_thing',
        object_id       => $event->object_id,
        pid             => $$
    };
}

note "generic events must be given an event type"; {
    ok !eval { $CLASS->new() };
    like $@, qr{^The event_type must be defined in the constructor};
}

done_testing;
