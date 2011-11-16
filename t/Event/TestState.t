#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }

use MyEventCollector;
use Test::Builder2::Formatter::Null;
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

    my $start = Test::Builder2::Event::TestStart->new;
    $state->post_event($start);
    is_deeply $state->history->events, [$start],        "events are posted";
}


note "default"; {
    my $default1 = $CLASS->default;
    my $default2 = $CLASS->default;
    my $new1 = $CLASS->create;
    my $new2 = $CLASS->create;

    is $default1, $default2, "default returns the same object";
    isnt $default1, $new1,     "create() does not return the default";
    isnt $new1, $new2,           "create() makes a fresh object";
}


note "isa"; {
    # Test both $class->isa and $object->isa
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
    is $event->event_type, "subtest_start",     "first level saw the start event";
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
    is $event->event_type, "subtest_end",     "first level saw the start event";
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

    my $first_stream_start = Test::Builder2::Event::TestStart->new;
    $state->post_event($first_stream_start);

    my $first_subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($first_subtest_start);
    is $first_subtest_start->depth, 1;

    my $second_stream_start = Test::Builder2::Event::TestStart->new;
    $state->post_event($second_stream_start);

    my $second_subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($second_subtest_start);
    is $second_subtest_start->depth, 2;

    my $second_subtest_ec = $state->current_coordinator;

    my $second_subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($second_subtest_end);
    is $second_subtest_end->history, $second_subtest_ec->history;

    my $second_stream_end = Test::Builder2::Event::TestEnd->new;
    $state->post_event($second_stream_end);

    my $first_subtest_ec = $state->current_coordinator;

    my $first_subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($first_subtest_end);
    is $first_subtest_end->history, $first_subtest_ec->history;

    my $first_stream_end = Test::Builder2::Event::TestEnd->new;
    $state->post_event($first_stream_end);

    is_deeply [map { $_->event_type } @{$state->history->events}],
              ["test_start", "subtest_start", "subtest_end", "test_end"],
              "original level saw the right events";

    is_deeply [map { $_->event_type } @{$first_subtest_ec->history->events}],
              ["test_start", "subtest_start", "subtest_end", "test_end"],
              "first subtest saw the right events";

    is_deeply [map { $_->event_type } @{$second_subtest_ec->history->events}],
              [],
              "second subtest saw the right events";
}


note "watchers are asked to provide their handler"; {
    # Some classes useful for testing subtest_handler is called correctly
    {
        package MyHistory;
        use Test::Builder2::Mouse;
        extends "Test::Builder2::History";

        has denial =>
          is            => 'rw',
          isa           => 'Int';

        # Just something to know the handler got called
        sub subtest_handler {
            my $self = shift;
            my $event = shift;

            ::isa_ok $event, "Test::Builder2::Event::SubtestStart";

            return $self->new( denial => 5 );
        }
    }

    {
        package MyNullFormatter;
        use Test::Builder2::Mouse;
        extends "Test::Builder2::Formatter::Null";

        has depth => 
          is            => 'rw',
          isa           => 'Int',
          default       => 0;

        # Just something to know the handler got called
        sub subtest_handler {
            my $self = shift;
            my $event = shift;

            ::isa_ok $event, "Test::Builder2::Event::SubtestStart";

            return $self->new( depth => $event->depth );
        }
    }

    {
        package MyEventCollectorSeesAll;
        use Test::Builder2::Mouse;
        extends "MyEventCollector";

        # A handler that returns itself
        sub subtest_handler {
            my $self = shift;
            my $event = shift;

            ::isa_ok $event, "Test::Builder2::Event::SubtestStart";

            return $self;
        }
    }

    note "...init a bunch of watchers with subtest_handler overrides";
    my $formatter1 = Test::Builder2::Formatter::Null->new;
    my $formatter2 = MyNullFormatter->new;
    my $seesall    = MyEventCollectorSeesAll->new;
    my $collector  = MyEventCollector->new;
    my $history   = MyHistory->new;
    my $state = $CLASS->create(
        formatters      => [$formatter1, $formatter2],
        history         => $history,
        early_watchers  => [$formatter2, $seesall],
        late_watchers   => [$formatter2, $collector],
    );

    note "...starting the subtest";
    my $subtest_start = Test::Builder2::Event::SubtestStart->new;
    $state->post_event($subtest_start);

    note "...checking the sub watchers were initialized from their parent's classes";
    isa_ok $state->formatters->[0],     ref $formatter1;
    isa_ok $state->formatters->[1],     ref $formatter2;
    isa_ok $state->history,             ref $history;
    isa_ok $state->early_watchers->[0], ref $formatter2;
    isa_ok $state->early_watchers->[1], ref $seesall;
    isa_ok $state->late_watchers->[0],  ref $formatter2;
    isa_ok $state->late_watchers->[1],  ref $collector;

    note "...checking the sub watchers made new objects (or didn't)";
    isnt $state->formatters->[0],     $formatter1;
    isnt $state->formatters->[1],     $formatter2;
    isnt $state->history,             $history;
    isnt $state->early_watchers->[0], $formatter2;
    is   $state->early_watchers->[1], $seesall;
    isnt $state->late_watchers->[0],  $formatter2;
    isnt $state->late_watchers->[1],  $collector;

    note "...checking special subtest_handler methods were called";
    is $state->formatters->[1]->depth,          1;
    is $state->history->denial,                 5;
    is $state->early_watchers->[0]->depth,      1;
    is $state->late_watchers->[0]->depth,       1;

    # Start and end an empty subtest
    my $substream_start = Test::Builder2::Event::SubtestStart->new;
    my $substream_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($_) for $substream_start, $substream_end;

    my $subtest_end = Test::Builder2::Event::SubtestEnd->new;
    $state->post_event($subtest_end);

    is_deeply [map { $_->event_id } $subtest_start, $subtest_end],
              [map { $_->event_id } @{$history->events}];

    is_deeply [map { $_->event_id } $subtest_start, $substream_start, $substream_end, $subtest_end],
              [map { $_->event_id } @{$seesall->events}],
              "A watcher can see all if it chooses";
}

done_testing;
