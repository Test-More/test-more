#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Builder2::Result;

use_ok "Test::Builder2::Formatter::Null";

my $null = Test::Builder2::Formatter::Null->new(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);

{
    $null->begin;
    is $null->streamer->read, "", "begin()";
}

{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $null->result($result);
    is(
      $null->streamer->read,
      "",
    );
}

{
    $null->end;
    is(
        $null->streamer->read,
        "",
        "nothing output at end of testing",
    );
}

done_testing();
