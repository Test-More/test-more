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

# Testing initialization
{
    my $history = new_ok $CLASS;

    is_deeply $history->results,        [];
}


# accept_result
{
    my $history = new_ok $CLASS;

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
    my $history = new_ok $CLASS;

    ok !eval {
        $history->accept_results($Pass, { passed => 1 }, $Fail);
    };
    like $@, qr/takes Result objects/;
}


done_testing;
