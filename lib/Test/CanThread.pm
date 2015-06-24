package Test::CanThread;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Capabilities qw/CAN_THREAD/;

sub import {
    return unless CAN_THREAD;
    my $ctx = context();
    $ctx->plan(0, "SKIP", "This test requires a perl capable of threading.");
}

1;
