#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use Test::Builder::NoOutput;
use Test::More;

use TB2::Tester;

note "Can call expected_tests() to set the plan"; {
    my $tb = Test::Builder->new;

    my $history = capture {
        $tb->expected_tests(4);
    };

    my $events = $history->events;

    event_like $events->[0], {
        event_type => "test_start"
    };
    event_like $events->[1], {
        event_type              => "set_plan",
        asserts_expected        => 4
    };

    ok !$events->[2];
}

done_testing(3);
