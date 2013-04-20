#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More coordinate_forks => 1;

subtest 'foo' => sub {
    pass 'parent one';
    pass 'parent two';
    my $pid = fork;
    unless ($pid) {
        pass 'child one';
        pass 'child two';
        exit;
    }
    wait;
    pass 'parent three';
};

done_testing;

