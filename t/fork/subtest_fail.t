#!/usr/bin/perl -w

# Make sure a subtest in a fork with a failing test is recorded.

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
    ),
    coordinate_forks => 1
);


# Run a test with a bunch of forks
{
    $State->post_event(
        TB2::Event::SetPlan->new( asserts_expected => 11 )
    );

    if ( fork ) {               # parent
        for (1..10) {
            $State->post_event(
                TB2::Result->new_result( pass => 1 )
            );
        }
    } else {                    # child
        # A subtest with one failing test
        $State->post_event(
            TB2::Event::SubtestStart->new
        );

        $State->post_event(
            TB2::Event::SetPlan->new( asserts_expected => 10 )
        );

        for (1..9) {
            $State->post_event(
                TB2::Result->new_result( pass => 1 )
            );
        }

        $State->post_event(
            TB2::Result->new_result( pass => 0 )
        );

        my $subtest_end = TB2::Event::SubtestEnd->new;
        $State->post_event($subtest_end);
        $State->post_event($subtest_end->result);

        exit;
    }

    wait;

    $State->post_event(
        TB2::Event::TestEnd->new
    );
}


note "Events are shared"; {
    my $history = $State->history;

    is $history->result_count, 11;
    is $history->pass_count,   10;
    is $history->fail_count,    1;
    ok !$history->in_test;
    ok !$history->test_was_successful;
}

done_testing;
