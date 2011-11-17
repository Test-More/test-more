#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }
use MyEventCoordinator;
use TB2::Events;
use TB2::Formatter::Null;

my $null = TB2::Formatter::Null->new(
  streamer_class => 'TB2::Streamer::Debug'
);

my $ec = MyEventCoordinator->new(
    formatters => [$null]
);

{
    $ec->post_event( TB2::Event::TestStart->new );
    is $null->streamer->read, "", "test start";
}

{
    my $result = TB2::Result->new_result(
        pass     => 1,
        name     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $null->streamer->read,
      "",
    );
}

{
    $ec->post_event( TB2::Event::TestEnd->new );
    is(
        $null->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing();
