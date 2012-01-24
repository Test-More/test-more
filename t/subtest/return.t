#!/usr/bin/env perl -w

# Test that subtests return a Result

use strict;
use warnings;

use Test::More;

note "passing subtest"; {
    my $result = subtest "passing subtest" => sub {
        plan tests => 1;
        pass;
    };

    ok $result;
    is $result->name, "passing subtest";
}


note "skip all in subtest"; {
    my $result = subtest "skip all" => sub {
        plan skip_all => "It's friday!";
        pass;
    };

    ok $result;
    is $result->name, "skip all";
    ok $result->is_skip;
    is $result->reason, "It's friday!";
}

done_testing;
