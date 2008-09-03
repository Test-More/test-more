#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

my $CLASS = "Test::Builder2::History";
require_ok 'Test::Builder2::History';


# Testing initialization
{
    my $history = new_ok $CLASS;

    is $history->last_test_number,      0;
    is_deeply $history->history,        [];
    ok $history->should_keep_history;
}


# increment_test_number()
{
    my $history = new_ok $CLASS;

    $history->increment_test_number;
    is $history->last_test_number, 1;

    $history->increment_test_number(2);
    is $history->last_test_number, 3;

    $history->increment_test_number(-3);
    is $history->last_test_number, 0;

    ok !eval {
        $history->increment_test_number(1.1);
    };
    is $@, sprintf "increment_test_number\(\) takes an integer, not '1.1' at %s line %d\n",
      $0, __LINE__ - 3;
}


{
    my $history = new_ok $CLASS;

    $history->add_test_history( { ok => 1 } );
    is_deeply $history->history, [{ ok => 1 }];
    is_deeply [$history->summary], [1];

    is $history->last_test_number, 1;
    ok $history->is_passing;

    $history->add_test_history( { ok => 1 }, { ok => 0 } );
    is_deeply $history->history, [
        { ok => 1 }, { ok => 1 }, { ok => 0 }
    ];
    is_deeply [$history->summary], [1, 1, 0];

    is $history->last_test_number, 3;
    ok !$history->is_passing;

    # Try a history replacement
    $history->last_test_number(2);
    $history->add_test_history( { ok => 1 }, { ok => 1 } );
    is_deeply [$history->summary], [1, 1, 1, 1];
}


# should_keep_history
{
    my $history = new_ok $CLASS;

    $history->should_keep_history(0);
    $history->add_test_history( { ok => 1 } );
    is $history->last_test_number, 1;
    is_deeply $history->history, [];
}
