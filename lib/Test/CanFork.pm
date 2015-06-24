package Test::CanFork;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Capabilities qw/CAN_FORK/;

sub import {
    return if CAN_FORK;
    my $ctx = context();
    $ctx->plan(0, "SKIP", "This test requires a perl capable of forking.");
}

1;
