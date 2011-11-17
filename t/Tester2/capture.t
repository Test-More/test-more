#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Simple ();
use TB2::Tester;

note "capturing nothing"; {
    my $have = capture {};

    is_deeply $have->results, [];
    is_deeply $have->events, [];
}

note "capturing results"; {
    my $have = capture {
        package Foo;

        Test::Simple->import( tests => 2 );
        ok( 1, "a pass" );
        ok( 0, "a fail" );
    };

    my @results = @{ $have->results };
    is @results, 2;

    my @events = grep { $_->event_type ne 'result' } @{ $have->events };
    is @events, 2;

    event_like( $events[0], { event_type => "test_start" } );
    event_like( $events[1], { event_type => "set_plan" } );

    result_like(
        $results[0],
        { is_pass  => 1, name => "a pass", file => $0 }
    );

    result_like (
        $results[1],
        { is_pass  => 0, name => "a fail", file => $0 }
    );
}

done_testing;
