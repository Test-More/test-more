#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use Test::Builder2::Events;

use_ok 'Test::Builder2::Formatter::POSIX';

my $posix = Test::Builder2::Formatter::POSIX->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);

my $ec = MyEventCoordinator->new(
    formatters => [$posix]
);

{
    $ec->post_event(
        Test::Builder2::Event::StreamStart->new
    );
    is $posix->streamer->read, "Running $0\n", "stream start";
}

{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $posix->streamer->read,
      "PASS: basset hounds got long ears\n",
      "the right thing is emitted for a passing test",
    );
}


{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
        description     => "something something something description",
    );
    $ec->post_event($result);
    is(
      $posix->streamer->read,
      "FAIL: something something something description\n",
      "the right thing is emitted for a failing test",
    );
}


{
    $ec->post_event(
        Test::Builder2::Event::StreamEnd->new
    );
    is(
        $posix->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing(5);
