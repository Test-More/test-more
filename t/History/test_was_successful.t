#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;

my $CLASS = "TB2::History";
use_ok $CLASS;

note "no success until it's over"; {
    my $history = $CLASS->new;

    ok !$history->test_was_successful, "no events";
    ok $history->can_succeed;

    $history->accept_event( TB2::Event::TestStart->new );
    ok !$history->test_was_successful, "testing started";
    ok $history->can_succeed;

    $history->accept_event( TB2::Result->new_result( pass => 1 ) );
    $history->accept_event( TB2::Result->new_result( pass => 1 ) );
    ok !$history->test_was_successful, "passing tests, but testing not done";
    ok $history->can_succeed;

    $history->accept_event( TB2::Event::SetPlan->new( asserts_expected => 2 ) );
    ok !$history->test_was_successful, "plan satisfied, but testing not done";
    ok $history->can_succeed;

    $history->accept_event( TB2::Event::TestEnd->new );
    ok $history->test_was_successful,  "test is over";
    ok $history->can_succeed;
}


note "No plan seen"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Failed test"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 0 ),
      TB2::Result->new_result( pass => 1 );

    ok !$history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Too many tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    # One too many tests
    $history->accept_event($_) for
      TB2::Result->new_result( pass => 1 );

    ok !$history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Too few tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 4 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "No plan, passing tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( no_plan => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "No plan at end"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::SetPlan->new( no_plan => 1 ),
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "No plan, failing test"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( no_plan => 1 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( fail => 1 );

    ok !$history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "No plan, no tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( no_plan => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Non-zero exit"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Event::TestEnd->new;

    local $? = 1;
    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Skip plan, no tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( skip => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "Skip plan, passing tests"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( skip => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok !$history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


note "Some skip results"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1, skip => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "All skip results"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1, skip => 1 ),
      TB2::Result->new_result( pass => 1, skip => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "Todo pass"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1, todo => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "Todo fail"; {
    my $history = $CLASS->new;

    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 0, todo => 1 ),
      TB2::Result->new_result( pass => 1 );

    ok $history->can_succeed;

    $history->accept_event($_) for
      TB2::Event::TestEnd->new;

    ok $history->can_succeed;
    ok $history->test_was_successful;
}


note "Abort"; {
    my $history = $CLASS->new;

    # A test which would pass if not for the abort
    $history->accept_event($_) for
      TB2::Event::TestStart->new,
      TB2::Event::SetPlan->new( asserts_expected => 2 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Result->new_result( pass => 1 ),
      TB2::Event::Abort->new,
      TB2::Event::TestEnd->new;

    ok !$history->can_succeed;
    ok !$history->test_was_successful;
}


done_testing;
