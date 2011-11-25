#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
use Test::Builder::NoOutput;

use Test::More;

# Formatting may change if we're running under Test::Harness.
local $ENV{HARNESS_ACTIVE} = 0; 

note; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    is $tb->in_subtest, '0', 'After testing has started but outside a subtest.';
}

note; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->subtest('first subtest' => sub {
        is $tb->in_subtest, '1', 'After testing has started and inside a subtest.';
    });
}

note; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->subtest('first subtest' => sub {});

    is $tb->in_subtest, '0', 'After testing has started and after a subtest is done.';
}

done_testing;
