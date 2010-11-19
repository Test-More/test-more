#!/usr/bin/perl -w

# Test that setting $? doesn't affect subtest success

use strict;
use Test::More;

subtest foo => sub {
    plan tests => 1;
    $? = 1;
    pass('bar');
};

subtest foo2 => sub {
    plan tests => 1;
    pass('bar2');
    $? = 1;
};

done_testing(2);
