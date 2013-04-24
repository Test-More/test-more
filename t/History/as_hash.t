#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::History;
use TB2::EventCoordinator;
use TB2::Events;

note "Empty history object as_hash"; {
    my $history = TB2::History->new;

    is_deeply $history->as_hash, {
        counter                 => 0,
        event_count             => 0,
        fail_count              => 0,
        literal_fail_count      => 0,
        literal_pass_count      => 0,
        pass_count              => 0,
        result_count            => 0,
        skip_count              => 0,
        todo_count              => 0,

        object_id               => $history->object_id,

        subtest_depth           => 0,
        is_subtest              => 0,
        is_child_process        => 0,
        in_test                 => 0,
        done_testing            => 0,

        can_succeed             => 1,
        test_was_successful     => 0,
    };
}


note "Empty history object as_hash"; {
    my $ec = TB2::EventCoordinator->new(
        formatters => [],
    );
    my $history = $ec->history;

    my $plan          = TB2::Event::SetPlan->new( asserts_expected => 2 );
    my @results       = (TB2::Result->new_result( pass => 1 )) x 2;
    my $test_end      = TB2::Event::TestEnd->new;

    $ec->post_event($_) for ($plan, @results, $test_end);

    is_deeply $history->as_hash, {
        counter                 => 2,
        event_count             => 5,
        fail_count              => 0,
        literal_fail_count      => 0,
        literal_pass_count      => 2,
        pass_count              => 2,
        result_count            => 2,
        skip_count              => 0,
        todo_count              => 0,

        object_id               => $history->object_id,

        subtest_depth           => 0,
        is_subtest              => 0,
        is_child_process        => 0,
        in_test                 => 0,
        done_testing            => 1,

        can_succeed             => 1,
        test_was_successful     => 1,

        pid_at_test_start       => $$,

        plan                    => $plan->as_hash,
        test_end                => $test_end->as_hash,
        test_start              => $history->test_start->as_hash
    };
}

done_testing;
