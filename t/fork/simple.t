#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 43, coordinate_forks => 1;

use Time::HiRes qw/sleep/;

my $pid = fork();
if ($pid == 0) { # child
    for my $i (1..20) {
        ok 1, "child $i";
        sleep(rand()/10);
    }
    pass 'child finished';

    note "Child SyncStore directory: ".Test::Builder->new->test_state->sync_store->directory;

    1 while wait() != -1;
    exit;
}
elsif ($pid) { # parent
    for my $i (1..20) {
        ok 1, "parent $i";
        sleep(rand()/10);
    }
    pass 'parent finished';
    waitpid($pid, 0);
    pass 'wait ok';

    note "Parent SyncStore directory: ".Test::Builder->new->test_state->sync_store->directory;
}
else {
    die $!;
}
