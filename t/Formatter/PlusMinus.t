#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require "t/test.pl" }
use Test::Builder2::Events;

use_ok 'Test::Builder2::Formatter::PlusMinus';

sub new_formatter {
    return Test::Builder2::Formatter::PlusMinus->create(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
}


my $formatter = new_formatter();

# Begin
{
    $formatter->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    is $formatter->streamer->read, "";
}


# Pass
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $formatter->accept_result($result);
    is(
      $formatter->streamer->read,
      "+",
      "passing test"
    );
}


# Fail
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
        description     => "basset hounds got long ears",
    );
    $formatter->accept_result($result);
    is(
      $formatter->streamer->read,
      "-",
      "failing test"
    );
}


# Skip
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        description     => "basset hounds got long ears",
    );
    $formatter->accept_result($result);
    is(
      $formatter->streamer->read,
      "+",
      "skip test"
    );
}


# End
{
    $formatter->accept_event(
        Test::Builder2::Event::StreamEnd->new
    );
    is $formatter->streamer->read, "\n";
}


# Test out PlusMinus inside TB2.
{
    require Test::Builder2;
    my $tb = Test::Builder2->create;
    $tb->event_coordinator->formatters([ new_formatter ]);

    $tb->stream_start();
    $tb->ok(1);
    $tb->ok(0);
    $tb->stream_end();

    is $tb->formatter->streamer->read, "+-\n", "PlusMinus plus TB2";
}

done_testing();
