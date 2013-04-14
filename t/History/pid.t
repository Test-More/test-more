#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { require "t/test.pl"; }

use TB2::History;
use TB2::Events;


note "pid_at_test_start"; {
    my $history = TB2::History->new;

    for my $pid ((-int rand(2**15)), (int rand(2**15))) {
        $history->pid_at_test_start($pid);
        is $history->pid_at_test_start, $pid;
    }

    ok !eval { $history->pid_at_test_start(0); 1 }, "PID can't be zero";
}


note "Run a test through History with a negative PID which can happen on Windows"; {
    local $$ = -756;

    my $history = TB2::History->new;
    ok eval {
        $history->accept_event( TB2::Event::TestStart->new );
        $history->accept_event( TB2::Result->new_result( pass => 1 ) );
        $history->accept_event( TB2::Result->new_result( pass => 1 ) );
        $history->accept_event( TB2::Event::SetPlan->new( asserts_expected => 2 ) );
        $history->accept_event( TB2::Event::TestEnd->new );
        1;
    } or diag $@;
    ok $history->test_was_successful;

    ok !$history->is_child_process;
}

done_testing;
