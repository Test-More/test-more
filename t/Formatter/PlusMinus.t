#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require "t/test.pl" }
use MyEventCoordinator;
use TB2::Events;

use_ok 'TB2::Formatter::PlusMinus';

sub new_formatter {
    return TB2::Formatter::PlusMinus->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
}


my $formatter = new_formatter();

my $ec = MyEventCoordinator->new(
    formatters => [$formatter]
);


# Begin
{
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    is $formatter->streamer->read, "";
}


# Pass
{
    my $result = TB2::Result->new_result(
        pass     => 1,
        name     => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $formatter->streamer->read,
      "+",
      "passing test"
    );
}


# Fail
{
    my $result = TB2::Result->new_result(
        pass            => 0,
        name            => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $formatter->streamer->read,
      "-",
      "failing test"
    );
}


# Skip
{
    my $result = TB2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        name            => "basset hounds got long ears",
    );
    $ec->post_event($result);
    is(
      $formatter->streamer->read,
      "+",
      "skip test"
    );
}


# End
{
    $ec->post_event(
        TB2::Event::TestEnd->new
    );
    is $formatter->streamer->read, "\n";
}


# Test out PlusMinus inside TB2.
{
    require Test::Builder2;
    my $tb = Test::Builder2->create;
    $tb->test_state->formatters([ new_formatter ]);

    $tb->test_start();
    $tb->ok(1);
    $tb->ok(0);
    $tb->test_end();

    is $tb->formatter->streamer->read, "+-\n", "PlusMinus plus TB2";
}

done_testing();
