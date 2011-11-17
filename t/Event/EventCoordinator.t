#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
require MyEventCollector;
BEGIN { require 't/test.pl'; }

use Test::Builder2::Events;

my $CLASS = 'Test::Builder2::EventCoordinator';
use_ok $CLASS;


note("EC init"); {
    my $ec = $CLASS->new;
    is_deeply $ec->early_handlers, [], "early_handlers";
    is_deeply $ec->late_handlers,  [], "late_handlers";

    my $formatters = $ec->formatters;
    is @$formatters, 1;
    isa_ok $formatters->[0], "Test::Builder2::Formatter::TAP", "formatters";

    my $history = $ec->history;
    isa_ok $history, "Test::Builder2::History", "history";
}


note("EC->new takes args"); {
    my %args = (
        early_handlers  => [MyEventCollector->new],
        late_handlers   => [MyEventCollector->new],
        history         => MyEventCollector->new,
        formatters      => [MyEventCollector->new]
    );

    my $ec = $CLASS->new(
        %args
    );

    is $ec->early_handlers->[0], $args{early_handlers}->[0];
    is $ec->late_handlers->[0],  $args{late_handlers}->[0];
    is $ec->history,             $args{history};
    is $ec->formatters->[0],     $args{formatters}->[0];

    my @want = (@{$args{early_handlers}},
                @{$args{formatters}},
                $args{history},
                @{$args{late_handlers}}
               );

    is_deeply [$ec->all_handlers], \@want, "all_handlers";
}


note("add and clear"); {
    my $ec = $CLASS->new(
        formatters => [],
    );

    for my $getter (qw(early_handlers formatters late_handlers)) {
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
        early_handlers  => [MyEventCollector->new, MyEventCollector->new],
        late_handlers   => [MyEventCollector->new],
        history         => MyEventCollector->new,
        formatters      => [MyEventCollector->new]
    );

    my $ec = $CLASS->new(
        %args
    );

    my $result = Test::Builder2::Result->new_result;
    my $event  = Test::Builder2::Event::TestStart->new;
    $ec->post_event($result);
    $ec->post_event ($event);

    my @handlers = (@{$args{early_handlers}},
                    @{$args{late_handlers}},
                    $args{history},
                    @{$args{formatters}}
                   );
    for my $handler (@handlers) {
        is_deeply $handler->results, [$result], "result accepted";
        is_deeply $handler->events,  [$event], "event accepted";

        is_deeply $handler->coordinators, [$ec, $ec], "coordinator passed through";
    }
}


note "posting events to specific handlers"; {
    {
        package My::Handler::StartEnd;
        
        use Test::Builder2::Mouse;
        with "Test::Builder2::EventHandler";

        has starts =>
          is            => 'rw',
          isa           => 'ArrayRef',
          default       => sub { [] };

        has ends =>
          is            => 'rw',
          isa           => 'ArrayRef',
          default       => sub { [] };

        has others =>
          is            => 'rw',
          isa           => 'ArrayRef',
          default       => sub { [] };

        sub accept_test_start {
            my($self, $event, $ec) = @_;
            push @{$self->starts}, [$event, $ec];
        }

        sub accept_test_end {
            my($self, $event, $ec) = @_;
            push @{$self->ends}, [$event, $ec];            
        }

        sub accept_event {
            my($self, $event, $ec) = @_;
            push @{$self->others}, [$event, $ec];
        }
    }

    my $handler = My::Handler::StartEnd->new;

    my $ec = $CLASS->new(
        early_handlers  => [$handler],
        formatters      => []
    );

    my $start   = Test::Builder2::Event::TestStart->new;
    my $comment = Test::Builder2::Event::Comment->new( comment => "whatever" );
    my $result  = Test::Builder2::Result->new_result;
    my $end     = Test::Builder2::Event::TestEnd->new;
    $ec->post_event($start);
    $ec->post_event($comment);
    $ec->post_event($result);
    $ec->post_event($end);

    is_deeply $handler->starts, [[$start, $ec]];
    is_deeply $handler->ends,   [[$end, $ec]];
    is_deeply $handler->others, [[$comment, $ec], [$result, $ec]];
}

done_testing();
