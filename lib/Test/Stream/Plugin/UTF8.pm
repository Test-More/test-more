package Test::Stream::Plugin::UTF8;
use strict;
use warnings;

use Test::Stream::Sync;
use Test::Stream::Plugin;

sub load_ts_plugin {
    my $stack = Test::Stream::Sync->stack;
    $stack->top; # Make sure we have at least 1 hub

    my $warned = 0;
    for my $hub ($stack->all) {
        my $format = $hub->format;
        if (!$format || !$format->isa('Test::Stream::TAP')) {
            warn "Could not apply UTF8 to unknown formatter" unless $warned++;
            next;
        }

        $format->encoding('utf8');
    }
}

1;
