#!/usr/bin/perl

# Make sure ok() starts a stream if it needs to

use strict;
use warnings;

use Test::Builder2;

my $tb = Test::Builder2->singleton;

# ok() starts the stream automatically
{
    $tb->ok(1);

    my $history = $tb->history;
    my $start = grep { $_->event_type eq 'test start' } @{$history->events};
    $tb->ok( $start, "ok issued a test start" );
}

$tb->set_plan( no_plan => 1 );
$tb->test_end;
