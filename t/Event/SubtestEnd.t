#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::Event::SubtestEnd';
use_ok $CLASS;

use TB2::History;
use TB2::EventCoordinator;
use TB2::Events;

note "defaults"; {
    my $history = TB2::History->new;
    my $event = $CLASS->new(
        history => $history
    );
    isa_ok $event, $CLASS;

    is $event->history, $history;
    is $event->event_type, "subtest_end";
    is_deeply $event->as_hash, {
        coordinate_threads      => $event->coordinate_threads,
        event_type              => "subtest_end",
        object_id               => $event->object_id,
        history                 => $history,
        result                  => $event->result,
    };

    is $event->result->name, "No tests run in subtest";
}


note "simple result"; {
    my $ec = TB2::EventCoordinator->new;
    $ec->clear_formatters;
    $ec->post_event( $_ ) for
      TB2::Event::TestStart->new, 
      TB2::Event::SetPlan->new( asserts_expected => 1 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Event::TestEnd->new, 
   ;

    my $event = $CLASS->new(
        history         => $ec->history,
        subtest_start   => TB2::Event::SubtestStart->new(
            depth       => 1,
            name        => 'some subtest',
            directives  => ['todo'],
            reason      => 'Because I said so'
        )
    );

    # Just to make sure we set the conditions up right
    ok $event->history->test_was_successful;

    my $result = $event->result;
    ok $result;
    ok $result->is_todo;
    ok !$result->is_skip;
    ok $result->is_pass;
    is $result->name,   "some subtest";
    is $result->reason, "Because I said so";
    is $result->file, $event->file;
    is $result->line, $event->line;
}

done_testing;
