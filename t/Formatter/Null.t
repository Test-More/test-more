#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use Test::Builder2::Events;
use Test::Builder2::Formatter::Null;

my $null = Test::Builder2::Formatter::Null->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);

my $ec = MyEventCoordinator->create(
    formatters => [$null]
);

{
    $ec->post_event( Test::Builder2::Event::StreamStart->new );
    is $null->streamer->read, "", "stream start";
}

{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $null->streamer->read,
      "",
    );
}

{
    $ec->post_event( Test::Builder2::Event::StreamEnd->new );
    is(
        $null->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing();
