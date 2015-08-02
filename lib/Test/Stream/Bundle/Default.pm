package Test::Stream::Bundle::Default;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        sub { strict->import(); warnings->import() },

        qw/IPC TAP ExitSummary More Context Subtest Exception Warnings/,

        DeepCheck => [
            strict_compare  => {-as => 'is_deeply'},
            relaxed_compare => {-as => 'mostly_like'},
        ],
    );
}

1;
