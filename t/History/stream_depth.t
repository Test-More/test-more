#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder2::Events;
use Test::Builder2::History;


{
    my $history = Test::Builder2::History->new;
    is $history->stream_depth, 0;

    $history->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    is $history->stream_depth, 1;

    $history->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    is $history->stream_depth, 2;

    $history->accept_event(
        Test::Builder2::Event::StreamEnd->new
    );
    is $history->stream_depth, 1;

    $history->accept_event(
        Test::Builder2::Event::StreamEnd->new
    );
    is $history->stream_depth, 0;

    ok !eval {
        $history->accept_event(
            Test::Builder2::Event::StreamEnd->new
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

    require Test::Builder2::EventCoordinator;
    my $formatter = My::Formatter->new;
    my $ec = Test::Builder2::EventCoordinator->create(
        formatters      => [ $formatter ],
    );

    $ec->post_event(
        Test::Builder2::Event::StreamStart->new
    );

    is $formatter->last_depth_seen, 1;

    $ec->post_event(
        Test::Builder2::Event::StreamEnd->new
    );

    is $formatter->last_depth_seen, 0;
}


done_testing;
