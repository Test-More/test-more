#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    # Ensure things print immediately to make parent/child printing
    # more predictable.
    $|=1;

    require "t/test.pl";
}

my $CLASS = "TB2::SyncStore";

use_ok $CLASS;

note "creation"; {
     my $store = new_ok $CLASS;

     ok -d $store->directory;
}


note "directory sticks around through a fork"; {
    my $dir;

    {
        my $store = new_ok $CLASS;

        ok -d $store->directory;

        my $pid;
        if( $pid = fork ) { # parent
            note "Parent";
            ok -d $store->directory, "parent directory still exists";
        }
        else {       # child
            note "Child";
            sleep 1;       # let the parent go first
            next_test;     # account that the parent has done a test
            ok -d $store->directory, "child directory still exists";
            exit;
        }

        wait;

        next_test;  # account for the child's test

        ok -d $store->directory;

        # Don't store the object else File::Temp won't destroy it.
        $dir = $store->directory.'';
    }

    # We didn't accidentally store the File::Temp object.
    ok ! ref $dir;

    # The store object and File::Temp::Dir object is now destroyed
    ok !-d $dir;
}

done_testing;
