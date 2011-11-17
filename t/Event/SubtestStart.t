#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::Event::SubtestStart';
use_ok $CLASS;


note "defaults"; {
    my $event = $CLASS->new;
    isa_ok $event, $CLASS;

    is $event->depth, undef;
    is $event->event_type, "subtest_start";
    is_deeply $event->as_hash, {
        event_type      => "subtest_start",
        event_id        => $event->event_id,
        name            => '',
        directives      => [],
        reason          => ''
    };
}


note "depth"; {
    my $event = $CLASS->new( depth => 3, name => 'foo' );
    isa_ok $event, $CLASS;

    is $event->depth, 3;
    is_deeply $event->as_hash, {
        event_type      => "subtest_start",
        event_id        => $event->event_id,
        depth           => 3,
        name            => 'foo',
        directives      => [],
        reason          => ''
    };
}


note "depth must be positive"; {
    ok !eval { $CLASS->new( depth => 0 ); };
    ok !eval { $CLASS->new( depth => 1.5 ); };
    ok !eval { $CLASS->new( depth => -1 ); };
    ok !eval { $CLASS->new( depth => "one" ); };
}


done_testing;
