#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use TB2::Events;
use TB2::History;
use TB2::History::EventStorage;
use TB2::TestState;

my $State = TB2::TestState->create(
    formatters => [],
    history    => TB2::History->new(
        event_storage => TB2::History::EventStorage->new
    )
);


# Run a test with a bunch of forks
{
    $State->post_event(
        TB2::Event::SetPlan->new( asserts_expected => 30 )
    );

    # Turn on fork coordination after posting events to ensure
    # it writes out its state before continuing.
    $State->coordinate_forks(1);

    if ( fork ) {               # parent
        for (1..10) {
            note "Parent";
            $State->post_event(
                TB2::Result->new_result( pass => 1 )
            );
        }
    } else {                    # child
        if( fork ) {
            for (1..10) {
                note "Child";
                $State->post_event(
                    TB2::Result->new_result( pass => 1 )
                  );
            }
        }
        else {                  # grandchild
            for (1..10) {
                note "Grandchild";
                $State->post_event(
                    TB2::Result->new_result( pass => 1 )
                );
            }

            # Exit grandchild
            exit;
        }

        # Wait for the grandchild
        wait;

        # Exit child
        exit;
    }

    # Wait for the children to finish up.
    wait;

    $State->post_event(
        TB2::Event::TestEnd->new
    );
}

note "Events are shared"; {
    my $history = $State->history;

    is $history->result_count, 30;
    is $history->pass_count,   30;
    ok !$history->in_test;
    ok $history->test_was_successful;
}

done_testing;
