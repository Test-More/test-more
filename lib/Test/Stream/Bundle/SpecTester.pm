package Test::Stream::Bundle::SpecTester;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (qw/-Default -Spec -Tester/);
}

1;
