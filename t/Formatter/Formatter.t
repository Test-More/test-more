#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Builder2::Events;

BEGIN { require "t/test.pl" }

{
    package My::Formatter;
    use Test::Builder2::Mouse;

    extends 'Test::Builder2::Formatter';

    has ['events', 'results'] =>
        is      => 'rw',
        isa     => 'Int',
        default => 0
    ;

    sub INNER_accept_event {
        my $self = shift;
        $self->events( $self->events + 1 );
    }

    sub INNER_accept_result {
        my $self = shift;
        $self->results( $self->results + 1 );
    }
}


my $formatter = My::Formatter->create;
is $formatter->stream_depth, 0;

ok !eval {
    $formatter->accept_result;
}, "can't accept a result outside a stream";
like $@, qr{^\Qaccept_result() called outside a stream\E};
is $formatter->stream_depth, 0;

$formatter->accept_event(
    Test::Builder2::Event::StreamStart->new
);
is $formatter->events, 1;
is $formatter->stream_depth, 1;

$formatter->accept_event(
    Test::Builder2::Event::StreamStart->new
);
is $formatter->events, 2;
is $formatter->stream_depth, 2;

$formatter->accept_result;
$formatter->results, 1;

$formatter->accept_event(
    Test::Builder2::Event::StreamEnd->new
);
is $formatter->events, 3;
is $formatter->stream_depth, 1;

$formatter->accept_event(
    Test::Builder2::Event::StreamEnd->new
);
is $formatter->events, 4;
is $formatter->stream_depth, 0;

ok !eval {
    $formatter->accept_event(
        Test::Builder2::Event::StreamEnd->new
    );
};
is $formatter->stream_depth, 0;


ok !eval {
    $formatter->accept_result;
}, "can't accept a result outside a stream";
like $@, qr{^\Qaccept_result() called outside a stream\E};
is $formatter->stream_depth, 0;


done_testing();
