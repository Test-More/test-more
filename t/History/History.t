#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
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


# handle_result
{
    my $history = new_ok $CLASS;
    my $ec = MyEventCoordinator->new(
        history => $history
    );

    $ec->post_event( $Pass );
    is_deeply $history->results, [$Pass];

    ok $history->can_succeed;

    $ec->post_event( $Fail );
    is_deeply $history->results, [
        $Pass, $Fail
    ];

    ok !$history->can_succeed;
}


# handle_result argument check
{
    my $history = new_ok $CLASS;

    ok !eval {
        $history->handle_result({ passed => 1 });
    };
    like $@, qr/takes Result objects/;
}


done_testing;
