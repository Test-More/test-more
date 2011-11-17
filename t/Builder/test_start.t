#!/usr/bin/perl

# Test::Builder must allow that somebody else started the stream

use strict;
use warnings;

use Test::Builder;
use TB2::TestState;
use TB2::Events;

my $ec = TB2::TestState->default;

$ec->post_event(
    TB2::Event::TestStart->new
);

my $tb = Test::Builder->new;
$tb->ok(1);

$tb->done_testing;
