#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

my $CLASS = "Test::Builder2::History";
require_ok 'Test::Builder2::History';


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

    my @results = ({ ok => 1 }, { ok => 0 });
    $history1->add_test_history(@results);

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


{
    my $history = $create_ok->();

    $history->add_test_history( { ok => 1 } );
    is_deeply $history->results, [{ ok => 1 }];
    is_deeply [$history->summary], [1];

    is $history->next_test_number, 2;
    ok $history->is_passing;

    $history->add_test_history( { ok => 1 }, { ok => 0 } );
    is_deeply $history->results, [
        { ok => 1 }, { ok => 1 }, { ok => 0 }
    ];
    is_deeply [$history->summary], [1, 1, 0];

    is $history->next_test_number, 4;
    ok !$history->is_passing;

    # Try a history replacement
    $history->next_test_number(3);
    $history->add_test_history( { ok => 1 }, { ok => 1 } );
    is_deeply [$history->summary], [1, 1, 1, 1];
}


# should_keep_history
{
    my $history = $create_ok->();

    $history->should_keep_history(0);
    $history->add_test_history( { ok => 1 } );
    is $history->next_test_number, 2;
    is_deeply $history->results, [];
}
