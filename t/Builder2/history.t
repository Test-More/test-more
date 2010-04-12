#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use Test::Builder2::Result;


my $CLASS = "Test::Builder2::History";
require_ok 'Test::Builder2::History';


my $Pass = Test::Builder2::Result->new_result(
    pass => 1,
);

my $Fail = Test::Builder2::Result->new_result(
    pass => 0,
);

my $create_ok = sub {
    my $history = $CLASS->create;
    isa_ok $history, $CLASS;
    return $history;
};


# Testing initialization
{
    my $history = $create_ok->();

    is $history->counter->get,          0;
    is_deeply $history->results,        [];
    ok $history->should_keep_history;
}


# Test the singleton nature
{
    my $history1 = $CLASS->singleton;
    isa_ok $history1, $CLASS;
    my $history2 = $CLASS->singleton;
    isa_ok $history2, $CLASS;

    is $history1, $history2,            "new() is a singleton";
    is $history1, $CLASS->singleton,    "singleton() get";

    $history1->add_test_history($Pass, $Fail);

    is_deeply $history1->results, $history2->results;

    my $new_history = $create_ok->();
    $CLASS->singleton($new_history);
    is   $CLASS->singleton,  $new_history,  "singleton() set";
}


# add_test_history
{
    my $history = $create_ok->();

    $history->add_test_history( $Pass );
    is_deeply $history->results, [$Pass];
    is_deeply [$history->summary], [1];

    is $history->counter->get, 1;
    ok $history->is_passing;

    $history->add_test_history( $Pass, $Fail );
    is_deeply $history->results, [
        $Pass, $Pass, $Fail
    ];
    is_deeply [$history->summary], [1, 1, 0];

    is $history->counter->get, 3;
    ok !$history->is_passing;

    # Try a history replacement
    $history->counter->set(2);
    $history->add_test_history( $Pass, $Pass );
    is_deeply [$history->summary], [1, 1, 1, 1];
}


# add_test_history argument checks
{
    my $history = $create_ok->();

    ok !eval {
        $history->add_test_history($Pass, { passed => 1 }, $Fail);
    };
    like $@, qr/takes Result objects/;
}


# should_keep_history
{
    my $history = $create_ok->();

    $history->should_keep_history(0);
    $history->add_test_history( $Pass );
    is $history->counter->get, 1;
    is_deeply $history->results, [];
}


# create() has its own Counter
{
    my $history = $CLASS->singleton;
    my $other   = $CLASS->create;

    $history->counter->set(22);
    is $other->counter->get, 0,         "create() comes with its own Counter";
}
