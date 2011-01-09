#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

BEGIN {
    *CORE::GLOBAL::exit = sub {
        exit $_[0];
    };
}

use lib 't/lib';
use Test::Builder::NoOutput;

note "Can call skip_all() to set the plan"; {
    my $tb = Test::Builder::NoOutput->create;

    my @exits;
    no warnings 'redefine';
    local *CORE::GLOBAL::exit = sub {
        push @exits, $_[0] || 0;
    };

    ok $tb->skip_all;
    is $tb->read('out'), <<OUT, "outputs TAP version";
TAP version 13
1..0 # SKIP
OUT
    is_deeply \@exits, [0];

}

done_testing;
