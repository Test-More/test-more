#!/usr/bin/perl -w

use strict;
use lib 't/lib';
BEGIN { require 't/test.pl' }

use Test::Builder2::Events;

use_ok 'Test::Builder2::Formatter::Multi';
use_ok 'Test::Builder2::Formatter::PlusMinus';
use_ok 'Test::Builder2::Formatter::POSIX';

my $pm    = Test::Builder2::Formatter::PlusMinus->create(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);
my $posix = Test::Builder2::Formatter::POSIX->create(
  streamer_class => 'Test::Builder2::Streamer::Debug'
);
my $multi = Test::Builder2::Formatter::Multi->create;
is_deeply $multi->formatters, [];

$multi->add_formatters($pm, $posix);
is_deeply $multi->formatters, [$pm, $posix];


# Begin
{
    $multi->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    is $pm->streamer->read, "";
    is $posix->streamer->read, "Running $0\n";
}


# Pass
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        description     => "basset hounds got long ears",
    );
    $multi->accept_result($result);
    is($pm->streamer->read, "+", "passing test" );
    is($posix->streamer->read, "PASS: basset hounds got long ears\n", "passing test" );
}


# Fail
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
        description     => "basset hounds got long ears",
    );
    $multi->accept_result($result);
    is($pm->streamer->read, "-", "fail" );
    is($posix->streamer->read, "FAIL: basset hounds got long ears\n", "POSIX fail" );
}


# Skip
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        description     => "basset hounds got long ears",
    );
    $multi->accept_result($result);
    is($pm->streamer->read, "+", "skip" );
    is($posix->streamer->read, "UNTESTED: basset hounds got long ears\n" );
}


# End
{
    $multi->accept_event(
        Test::Builder2::Event::StreamEnd->new
    );
    is $pm->streamer->read, "\n";
    is $posix->streamer->read, "";
}

done_testing();
