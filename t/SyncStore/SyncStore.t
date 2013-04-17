#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

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
            ok -d $store->directory;
        }
        else {       # child
            ok -d $store->directory;
            exit;
        }

        wait;
        ok -d $store->directory;

        # Don't store the object else File::Temp won't destroy it.
        $dir = $store->directory.'';
    }

    # We didn't accidentally store the File::Temp object.
    ok ! ref $dir;

    # The store object and File::Temp::Dir object is now destroyed
    ok !-d $dir;
}
