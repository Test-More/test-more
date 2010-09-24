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

    is_deeply $history->results,        [];
}


# Test the singleton nature
{
    my $history1 = $CLASS->singleton;
    isa_ok $history1, $CLASS;
    my $history2 = $CLASS->singleton;
    isa_ok $history2, $CLASS;

    is $history1, $history2,            "new() is a singleton";

    my $new_history = $create_ok->();
    $CLASS->singleton($new_history);
    is   $CLASS->singleton,  $new_history,  "singleton() set";
}


# add_test_history
{
    my $history = $create_ok->();

    $history->add_test_history( $Pass );
    is_deeply $history->results, [$Pass];

    ok $history->is_passing;

    $history->add_test_history( $Pass, $Fail );
    is_deeply $history->results, [
        $Pass, $Pass, $Fail
    ];

    ok !$history->is_passing;

    # Try a history replacement
    $history->add_test_history( $Pass, $Pass );
}


# add_test_history argument checks
{
    my $history = $create_ok->();

    ok !eval {
        $history->add_test_history($Pass, { passed => 1 }, $Fail);
    };
    like $@, qr/takes Result objects/;
}


