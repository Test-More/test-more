#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use Test::Builder2::Events;
use Test::Builder2::History;


{
    my $history = Test::Builder2::History->new;
    my $ec = MyEventCoordinator->new( history => $history );

    is $history->stream_depth, 0;

    $ec->post_event(
        Test::Builder2::Event::TestStart->new
    );
    is $history->stream_depth, 1;

    $ec->post_event(
        Test::Builder2::Event::TestStart->new
    );
    is $history->stream_depth, 2;

    $ec->post_event(
        Test::Builder2::Event::TestEnd->new
    );
    is $history->stream_depth, 1;

    $ec->post_event(
        Test::Builder2::Event::TestEnd->new
    );
    is $history->stream_depth, 0;

    ok !eval {
        $ec->post_event(
            Test::Builder2::Event::TestEnd->new
        );
        1;
    };
    is $history->stream_depth, 0;
}


note "post order"; {
    {
        package My::Formatter;
        use Test::Builder2::Mouse;
        extends "Test::Builder2::Formatter";

        has last_depth_seen =>
          is            => 'rw',
          isa           => 'Int',
        ;

        sub accept_event {
            my($self, $event, $ec) = @_;

            $self->last_depth_seen( $ec->history->stream_depth );
        }
    }

    my $formatter = My::Formatter->new;
    my $ec = MyEventCoordinator->new(
        formatters      => [ $formatter ],
    );

    $ec->post_event(
        Test::Builder2::Event::TestStart->new
    );

    is $formatter->last_depth_seen, 1;

    $ec->post_event(
        Test::Builder2::Event::TestEnd->new
    );

    is $formatter->last_depth_seen, 0;
}


done_testing;
