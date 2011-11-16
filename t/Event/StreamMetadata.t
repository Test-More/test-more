#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::StreamMetadata;

note "Basic event"; {
    my $event = Test::Builder2::Event::StreamMetadata->new;

    is $event->event_type, "stream_metadata";

    is_deeply $event->as_hash, {
        event_id                => $event->event_id,
        event_type              => 'stream_metadata',
        metadata                => {},
    };
}

note "Basic event with metadata"; {
    my $event = Test::Builder2::Event::StreamMetadata->new(
        metadata        => { this => "that" }
    );

    my $data = $event->as_hash;
    is_deeply $event->as_hash, {
        event_id                => $event->event_id,
        event_type              => 'stream_metadata',
        metadata                => { this => 'that' },
    };
}

done_testing;
