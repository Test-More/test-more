#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Event::StreamMetadata;

note "Basic event"; {
    my $event = Test::Builder2::Event::StreamMetadata->new;

    is $event->event_type, "stream metadata";

    my $data = $event->as_hash;
    is keys %{$data->{metadata}},           0;
    is $data->{event_type},             "stream metadata";
}

note "Basic event with metadata"; {
    my $event = Test::Builder2::Event::StreamMetadata->new(
        metadata        => { this => "that" }
    );

    my $data = $event->as_hash;
    is $data->{metadata}{this},         "that";
    is $data->{event_type},             "stream metadata";
}

done_testing;
