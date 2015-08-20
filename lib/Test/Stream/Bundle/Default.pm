package Test::Stream::Bundle::Default;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        sub { strict->import(); warnings->import() },
        qw{
            IPC
            TAP
            ExitSummary
            Core
            Context
            Exception
            Warnings
            Compare
            Mock
        },
    );
}

1;
