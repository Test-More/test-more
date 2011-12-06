#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

my $CLASS = 'TB2::Event::TestMetadata';
use_ok $CLASS;

note "Basic event"; {
    my $event = $CLASS->new;

    is $event->event_type, "test_metadata";

    is_deeply $event->as_hash, {
        object_id                => $event->object_id,
        event_type              => 'test_metadata',
        metadata                => {},
    };
}

note "Basic event with metadata"; {
    my $event = $CLASS->new(
        metadata        => { this => "that" }
    );

    my $data = $event->as_hash;
    is_deeply $event->as_hash, {
        object_id                => $event->object_id,
        event_type              => 'test_metadata',
        metadata                => { this => 'that' },
    };
}

done_testing;
