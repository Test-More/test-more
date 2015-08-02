package Test::Stream::Bundle::Tester;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (qw/-Default Tester Intercept Grab LoadPlugin Context/);
}

1;
