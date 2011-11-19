#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use TB2::Result;


my $CLASS = "TB2::History";
require_ok 'TB2::History';


my $Pass = TB2::Result->new_result(
    pass => 1,
);

my $Fail = TB2::Result->new_result(
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

done_testing;
