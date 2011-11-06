#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }

use Test::Builder2::Events;

my $CLASS = 'Test::Builder2::TestState';
use_ok $CLASS;


note "new() does not work"; {
    ok !eval { $CLASS->new; };
    like $@, qr{^\QSorry, there is no new()};
}


note "create() and pass through"; {
    my $state = $CLASS->create(
        formatters => []
    );

    is_deeply $state->formatters, [],           "create() passes arguments through";
    isa_ok $state->history, "Test::Builder2::History";

    my $start = Test::Builder2::Event::StreamStart->new;
    $state->post_event($start);
    is_deeply $state->history->events, [$start],        "events are posted";
}


note "singleton"; {
    my $singleton1 = $CLASS->singleton;
    my $singleton2 = $CLASS->singleton;
    my $new1 = $CLASS->create;
    my $new2 = $CLASS->create;

    is $singleton1, $singleton2, "singleton returns the same object";
    isnt $singleton1, $new1,     "create() does not return the singleton";
    isnt $new1, $new2,           "create() makes a fresh object";
}


note "isa"; {
    for my $thing ($CLASS, $CLASS->create) {
        isa_ok $thing, $CLASS;
        isa_ok $thing, "Test::Builder2::EventCoordinator";
        ok !$thing->isa("Some::Other::Class");
    }
}


note "can"; {
    # Test both $class->can and $object->can
    for my $thing ($CLASS, $CLASS->create) {
        can_ok $thing, "formatters";
        can_ok $thing, "create";
        can_ok $thing, "pop_coordinator";

        ok !$thing->can("method_not_appearing_in_this_film");
    }
}


note "push/pop coordinators"; {
    my $state = $CLASS->create;

    my $first_ec  = $state->current_coordinator;
    my $second_ec = $state->push_coordinator;
    is $state->history, $second_ec->history;
    isnt $state->history, $first_ec->history;

    is $state->pop_coordinator, $second_ec;
    is $state->history, $first_ec->history;
}


note "push our own coordinator"; {
    my $state = $CLASS->create;

    require Test::Builder2::EventCoordinator;
    my $ec = Test::Builder2::EventCoordinator->new;

    $state->push_coordinator($ec);

    is $state->current_coordinator, $ec;
}


note "popping the last coordinator"; {
    my $state = $CLASS->create;

    ok !eval { $state->pop_coordinator; 1 };
    like $@, qr{^The last coordinator cannot be popped};
}


note "basic subtest"; {
    my $state = $CLASS->create(
        formatters => []
    );

    note "...starting a subtest";
    my $first_ec = $state->current_coordinator;
    my $subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($subtest_start);
    my $second_ec = $state->current_coordinator;

    isnt $first_ec, $second_ec, "creates a new coordinator";

    note "...checking coordinator state";
    my $first_history  = $first_ec->history;
    my $second_history = $second_ec->history;
    is $first_history->event_count, 1;
    my $event = $first_history->events->[0];
    is $event->event_id, $subtest_start->event_id;
    is $event->event_type, "subtest start",     "first level saw the start event";
    is $event->depth, 1,                        "  depth was correctly set";
    is $second_history->event_count, 0,     "second level did not see the start event";


    note "...ending the subtest";
    my $subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($subtest_end);
    is $subtest_end->history, $second_history,  "second level history attached to the event";
    is $second_history->event_count, 0,         "  second level did not see the end event";
    is $state->current_coordinator, $first_ec,  "stack popped";

    is $first_history->event_count, 2;
    $event = $first_history->events->[1];
    is $event->event_id, $subtest_end->event_id;
    is $event->event_type, "subtest end",     "first level saw the start event";
    is $event->history, $second_history;
}


note "honor event presets"; {
    my $state = $CLASS->create(
        formatters => []
    );

    note "...post a subtest with a pre defined depth";
    my $subtest_start = Test::Builder2::Event::SubtestStart->new(
        depth => 93
    );
    my $history = $state->history;
    $state->post_event($subtest_start);
    is $history->events->[0]->depth, 93;

    note "...post a subtest with a alternate history";
    my $alternate_history = Test::Builder2::History->new;
    my $subtest_end = Test::Builder2::Event::SubtestEnd->new(
        history => $alternate_history
    );
    $state->post_event($subtest_end);
    is $state->history->events->[-1]->history, $alternate_history;
}


note "nested subtests"; {
    my $state = $CLASS->create(
        formatters => []
    );

    my $first_stream_start = Test::Builder2::Event::StreamStart->new;
    $state->post_event($first_stream_start);

    my $first_subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($first_subtest_start);
    is $first_subtest_start->depth, 1;

    my $second_stream_start = Test::Builder2::Event::StreamStart->new;
    $state->post_event($second_stream_start);

    my $second_subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($second_subtest_start);
    is $second_subtest_start->depth, 2;

    my $second_subtest_ec = $state->current_coordinator;

    my $second_subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($second_subtest_end);
    is $second_subtest_end->history, $second_subtest_ec->history;

    my $second_stream_end = Test::Builder2::Event::StreamEnd->new;
    $state->post_event($second_stream_end);

    my $first_subtest_ec = $state->current_coordinator;

    my $first_subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($first_subtest_end);
    is $first_subtest_end->history, $first_subtest_ec->history;

    my $first_stream_end = Test::Builder2::Event::StreamEnd->new;
    $state->post_event($first_stream_end);

    is_deeply [map { $_->event_type } @{$state->history->events}],
              ["stream start", "subtest start", "subtest end", "stream end"],
              "original level saw the right events";

    is_deeply [map { $_->event_type } @{$first_subtest_ec->history->events}],
              ["stream start", "subtest start", "subtest end", "stream end"],
              "first subtest saw the right events";

    is_deeply [map { $_->event_type } @{$second_subtest_ec->history->events}],
              [],
              "second subtest saw the right events";
}

done_testing;
