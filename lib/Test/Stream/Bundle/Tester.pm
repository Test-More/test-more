package Test::Stream::Bundle::Tester;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        qw/-Default Intercept Grab LoadPlugin Context/,
        Compare => ['-all'],
    );
}

1;
