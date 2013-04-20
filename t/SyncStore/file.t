#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $CLASS = "TB2::SyncStore::File";

use_ok $CLASS;

note "basic usage"; {
    my $file = TB2::SyncStore::File->new;
    ok $file->file, "has a filename";

    $file->get_lock;

    my $text = "Basset hounds got long ears!";
    $file->write_file($text);
    is $file->read_file, $text, "read/write to the file";

    $file->write_file("a");
    is $file->read_file, "a", "write_file truncates the file";

    my $fh = $file->fh;
    is join("", <$fh>), "a", "fh is seeked to the beginning";

    $fh = $file->fh;
    is join("", <$fh>), "a", "  double checking that";
}


note "cleanup"; {
    my $path = do {
        my $file = TB2::SyncStore::File->new;
        $file->write_file("foo");
        ok -e $file->file;
        $file->file;
    };
    ok !-e "$path", "it cleans up after itself";
}

note "test locking"; SKIP: {
    skip "need fork" unless has_fork;

    my $file = $CLASS->new;

    my $pid;
    if( $pid = fork ) {                 # parent
        $file->get_lock;
        note "Parent lock";
        $file->write_file("foo");
        sleep 2;
        $file->unlock;
        note "Parent unlock";
    }
    else {                              # child
        sleep 1;
        $file->get_lock;
        note "Child lock";
        is $file->read_file, "foo";
        $file->unlock;
        note "Child unlock";
        exit;
    }

    waitpid $pid, 0;
    next_test;  # for the one the child did
    ok -e $file->file, "child did not delete the file";
}

done_testing;
