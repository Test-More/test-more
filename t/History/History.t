#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

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


# accept_result
{
    my $history = $create_ok->();

    $history->accept_result( $Pass );
    is_deeply $history->results, [$Pass];

    ok $history->is_passing;

    $history->accept_results( $Pass, $Fail );
    is_deeply $history->results, [
        $Pass, $Pass, $Fail
    ];

    ok !$history->is_passing;

    # Try a history replacement
    $history->accept_results( $Pass, $Pass );
}


# accept_results argument checks
{
    my $history = $create_ok->();

    ok !eval {
        $history->accept_results($Pass, { passed => 1 }, $Fail);
    };
    like $@, qr/takes Result objects/;
}


done_testing;
