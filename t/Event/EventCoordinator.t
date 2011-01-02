#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
require MyEventCollector;
BEGIN { require 't/test.pl'; }

my $CLASS = 'Test::Builder2::EventCoordinator';
use_ok $CLASS;


note("EC->singleton initialization"); {
    my $ec = $CLASS->singleton;
    is_deeply $ec->early_watchers, [], "early_watchers";
    is_deeply $ec->late_watchers,  [], "late_watchers";

    my $formatters = $ec->formatters;
    is @$formatters, 1;
    is $formatters->[0], Test::Builder2::Formatter->singleton, "formatters";

    my $histories = $ec->histories;
    is @$histories, 1;
    is $histories->[0],  Test::Builder2::History->singleton, "histories";
}


note("EC->create init"); {
    my $ec = $CLASS->create;
    is_deeply $ec->early_watchers, [], "early_watchers";
    is_deeply $ec->late_watchers,  [], "late_watchers";

    my $formatters = $ec->formatters;
    is @$formatters, 1;
    isa_ok $formatters->[0], "Test::Builder2::Formatter", "formatters";
    isnt $formatters->[0], Test::Builder2::Formatter->singleton, "  not the singleton";

    my $histories = $ec->histories;
    is @$histories, 1;
    isa_ok $histories->[0], "Test::Builder2::History", "histories";
    isnt $histories->[0], Test::Builder2::History->singleton, "  not the singleton";
}


note("EC->create takes args"); {
    my %args = (
        early_watchers  => [MyEventCollector->new],
        late_watchers   => [MyEventCollector->new],
        histories       => [MyEventCollector->new],
        formatters      => [MyEventCollector->new]
    );

    my $ec = $CLASS->create(
        %args
    );

    is $ec->early_watchers->[0], $args{early_watchers}->[0];
    is $ec->late_watchers->[0], $args{late_watchers}->[0];
    is $ec->histories->[0], $args{histories}->[0];
    is $ec->formatters->[0], $args{formatters}->[0];

    my @want = (@{$args{early_watchers}},
                @{$args{formatters}},
                @{$args{histories}},
                @{$args{late_watchers}}
               );

    is_deeply [$ec->all_watchers], \@want, "all_watchers";
}


note("add and clear"); {
    my $ec = $CLASS->create(
        formatters => [],
        histories  => []
    );

    for my $getter (qw(early_watchers formatters histories late_watchers)) {
        note("  $getter");
        my $adder       = "add_$getter";
        my $clearer     = "clear_$getter";

        my @want = (MyEventCollector->new, MyEventCollector->new);
        $ec->$adder( @want );
        is_deeply $ec->$getter(), \@want, "add";

        my @want_more = (MyEventCollector->new, MyEventCollector->new);
        $ec->$adder( @want_more );
        is_deeply $ec->$getter(), [@want, @want_more], "add more";

        $ec->$clearer;
        is_deeply $ec->$getter, [], "clear";
    }
}


note("posting"); {
    my %args = (
        early_watchers  => [MyEventCollector->new, MyEventCollector->new],
        late_watchers   => [MyEventCollector->new],
        histories       => [MyEventCollector->new],
        formatters      => [MyEventCollector->new]
    );

    my $ec = $CLASS->create(
        %args
    );

    my $result = { foo => 42 };
    my $event  = { bar => 23 };
    $ec->post_result($result);
    $ec->post_event ($event);

    my @watchers = (@{$args{early_watchers}},
                    @{$args{late_watchers}},
                    @{$args{histories}},
                    @{$args{formatters}}
                   );
    for my $watcher (@watchers) {
        is_deeply $watcher->results, [$result], "result accepted";
        is_deeply $watcher->events,  [$event], "event accepted";

        is_deeply $watcher->coordinators, [$ec, $ec], "coordinator passed through";
    }
}


done_testing();
