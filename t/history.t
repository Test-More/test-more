#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use Test::Builder2::Result;


my $CLASS = "Test::Builder2::History";
require_ok 'Test::Builder2::History';


my $Pass = Test::Builder2::Result->new(
    raw_passed => 1
);

my $Fail = Test::Builder2::Result->new(
    raw_passed => 0
);

my $create_ok = sub {
    my $history = $CLASS->create;
    isa_ok $history, $CLASS;
    return $history;
};


# Testing initialization
{
    my $history = $create_ok->();

    is $history->next_test_number,      1;
    is_deeply $history->results,        [];
    ok $history->should_keep_history;
}


# Test the singleton nature
{
    my $history1 = new_ok($CLASS);
    my $history2 = new_ok($CLASS);

    is $history1, $history2,            "new() is a singleton";
    is $history1, $CLASS->singleton,    "singleton() get";

    $history1->add_test_history($Pass, $Fail);

    is_deeply $history1->results, $history2->results;

    $CLASS->singleton($create_ok->());
    isnt $history1,       $CLASS->singleton,  "singleton() set";
    is   new_ok($CLASS),  $CLASS->singleton,  "new() changed";
}


# increment_test_number()
{
    my $history = $create_ok->();

    $history->increment_test_number;
    is $history->next_test_number, 2;

    $history->increment_test_number(2);
    is $history->next_test_number, 4;

    $history->increment_test_number(-3);
    is $history->next_test_number, 1;

    ok !eval {
        $history->increment_test_number(1.1);
    };
    is $@, sprintf "increment_test_number\(\) takes an integer, not '1.1' at %s line %d\n",
      $0, __LINE__ - 3;
}


# add_test_history
{
    my $history = $create_ok->();

    $history->add_test_history( $Pass );
    is_deeply $history->results, [$Pass];
    is_deeply [$history->summary], [1];

    is $history->next_test_number, 2;
    ok $history->is_passing;

    $history->add_test_history( $Pass, $Fail );
    is_deeply $history->results, [
        $Pass, $Pass, $Fail
    ];
    is_deeply [$history->summary], [1, 1, 0];

    is $history->next_test_number, 4;
    ok !$history->is_passing;

    # Try a history replacement
    $history->next_test_number(3);
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
    is $history->next_test_number, 2;
    is_deeply $history->results, [];
}
