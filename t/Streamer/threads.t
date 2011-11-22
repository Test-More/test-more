#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

my $Have_Threads;
use Config;
BEGIN {
    # Have to load threads before threads::shared.
    $Have_Threads = $Config{'useithreads'} && eval { require threads; 'threads'->import; 1; };
}
use threads::shared;
skip_all "this perl does not have threads" if !$Have_Threads;

use TB2::Streamer::Print;

note "clone a streamer"; {
    my $print = TB2::Streamer::Print->new;
    $print = shared_clone($print);

    $print->write(out => "1..4\n", "ok 1 - parent\n");

    "threads"->create(sub {
        $print->write(out => "ok 2 - thread one\n");
    })->join;

    "threads"->create(sub {
        $print->write(out => "ok 3 - thread two\n");
    })->join;

    $print->write(out => "ok 4 - parent after threads\n");
}
