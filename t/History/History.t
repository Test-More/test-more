#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use TB2::Result;

my $FILE = __FILE__;
my $QFILE = quotemeta($FILE);
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

    is_deeply $history->result_count, 0;
    is_deeply $history->event_count,  0;
}


# handle_result
{
    my $history = new_ok $CLASS;
    my $ec = MyEventCoordinator->new(
        history => $history
    );

    $ec->post_event( $Pass );
    is_deeply $history->result_count, 1;

    ok $history->can_succeed;

    $ec->post_event( $Fail );
    is_deeply $history->result_count, 2;

    ok !$history->can_succeed;
}

# object_id
{
    my $history1 = new_ok $CLASS;
    my $history2 = new_ok $CLASS;

    ok $history1->object_id;
    ok $history2->object_id;

    isnt $history1->object_id, $history2->object_id, "history object_ids are unique";
}

note "Turn off event storage";
{
    my $history = $CLASS->new(
        store_events => 0
    );

    $history->accept_event( $Pass ) for 1..3;
    is $history->result_count, 3;
    is $history->event_count, 3;

    ok !eval { $history->events; 1 };
    like $@, qr{^Events are not stored at $QFILE line @{[ __LINE__ - 1 ]}\.?\n};

    ok !eval { $history->results; 1 };
    like $@, qr{^Results are not stored at $QFILE line @{[ __LINE__ - 1 ]}\.?\n};

    ok !eval { $history->store_events(1) }, "can't turn on storage for an existing object";
}

done_testing;
