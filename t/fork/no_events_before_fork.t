#!/usr/bin/perl -w

# Test forking when there are no events before forking

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More coordinate_forks => 1;

if (fork) {
    note("$$ is after the fork");
    pass("Parent");
}
else {
    note("$$ is after the fork");
    pass("Child");
    exit;
}

wait;

done_testing;
