#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 4, coordinate_forks => 1;

main();
exit 0;

sub main {
    my $pid = fork;
    if ($pid==0) {              # child
        pass;
        return;
    } elsif (defined $pid) {    # parent
        pass;

        1 while wait() == -1;

        my $pid = fork();
        if ($pid==0) {                  # child
            pass;
            return;
        } elsif (defined $pid) {        # parent
            pass;
            1 while wait() == -1;
            return;
        } else {                        # fork failed
            die "fork failed: $!";
        }
    } else {                            # fork failed
        die "fork failed: $!";
    }
}
