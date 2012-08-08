#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 30, coordinate_forks => 1;

for my $num (1..10) {
    my $pid = fork();
    if ($pid == 0) {            # child
        pass "child $num";
        exit;
    }
    elsif (defined($pid)) {     # parent
        pass "parent $num";

        waitpid($pid, 0);

        pass 'wait ok';
    }
    else {                      # fork failure
        die "fork failed: $!";
    }
}
