#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use TB2::Events;

use_ok 'TB2::Formatter::POSIX';

my $posix = TB2::Formatter::POSIX->new(
  streamer_class => 'TB2::Streamer::Debug'
);

my $ec = MyEventCoordinator->new(
    formatters => [$posix]
);

{
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    is $posix->streamer->read, "Running $0\n", "test start";
}

{
    my $result = TB2::Result->new_result(
        pass     => 1,
        name     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $posix->streamer->read,
      "PASS: basset hounds got long ears\n",
      "the right thing is emitted for a passing test",
    );
}


{
    my $result = TB2::Result->new_result(
        pass     => 0,
        name     => "something something something description",
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
        TB2::Event::TestEnd->new
    );
    is(
        $posix->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing(5);
