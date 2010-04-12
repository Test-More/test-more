#!/usr/bin/perl -w

use strict;
use lib 't/lib';

use Test::More;

use Test::Builder2;
use Test::Builder2::Result;

use_ok 'Test::Builder2::Formatter::PlusMinus';

sub new_formatter {
    return Test::Builder2::Formatter::PlusMinus->new(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
}


my $formatter = new_formatter();

# Begin
{
    $formatter->begin;
    is $formatter->streamer->read, "";
}


# Pass
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $formatter->result($result);
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
    $formatter->result($result);
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
    $formatter->result($result);
    is(
      $formatter->streamer->read,
      "+",
      "skip test"
    );
}


# End
{
    $formatter->end();
    is $formatter->streamer->read, "\n";
}


# Test out PlusMinus inside TB2.
{
    my $tb = Test::Builder2->new;
    $tb->set_formatter( new_formatter() );

    $tb->ok(1);
    $tb->ok(0);
    $tb->stream_end();

    is $tb->formatter->streamer->read, "+-\n", "PlusMinus plus TB2";
}

done_testing();
