#!/usr/bin/perl

# Test::Builder must allow that somebody else started the stream

use strict;
use warnings;

use Test::Builder;
use Test::Builder2::EventCoordinator;
use Test::Builder2::Events;

my $ec = Test::Builder2::EventCoordinator->singleton;

$ec->post_event(
    Test::Builder2::Event::StreamStart->new
);

my $tb = Test::Builder->new;
$tb->ok(1);

$tb->done_testing;
