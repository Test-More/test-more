#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;

use Test::Builder2::Result;

use_ok 'Test::Builder2::Formatter::POSIX';

my $posix = Test::Builder2::Formatter::POSIX->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);

{
    $posix->begin;
    is $posix->streamer->read, "Running $0\n", "begin()";
}

{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $posix->result($result);
    is(
      $posix->streamer->read,
      "PASS: basset hounds got long ears\n",
      "the right thing is emitted for passing test",
    );
}

{
    $posix->end;
    is(
        $posix->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing(4);
