#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN {
    require "t/test.pl";
    plan(skip_all => "JSON::PP required") unless eval { require JSON::PP };
}
use MyEventCoordinator;
use TB2::Events;

use JSON::PP;

use_ok 'TB2::Formatter::JSON';

my $formatter = TB2::Formatter::JSON->new(
  streamer_class => 'TB2::Streamer::Debug'
);

my $ec = MyEventCoordinator->new(
    formatters => [$formatter]
);

{
    my @events = (
        TB2::Event::TestStart->new,
        TB2::Event::SetPlan->new( asserts_expected => 2 ),
        TB2::Result->new_result( pass => 1 ),
        TB2::Result->new_result( pass => 0 ),
        TB2::Event::TestEnd->new,
    );

    $ec->post_event($_) for @events;

    my $json = $formatter->streamer->read;

    is_deeply decode_json($json), [map { $_->as_hash } @events];
}

done_testing;
