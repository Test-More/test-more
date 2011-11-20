#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = 'TB2::Streamer::Print';
use_ok $CLASS;


note "stdout & stderr only duplicated once"; {
    my $first = $CLASS->new;
    my $second = $CLASS->new;

    is $first->stdout, $second->stdout, "stdout";
    is $first->stderr, $second->stderr, "stderr";

    isnt $first->stdout, $first->stderr, "stdout and stderr are different";
}

done_testing;
