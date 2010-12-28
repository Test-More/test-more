#!/usr/bin/perl

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

note "plan at the start"; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->no_header(1);
    $tb->plan( tests => 1 );

    is $tb->read, '',       "no_header supresses initial plan and TAP version";
}

note "plan at the end"; {
    my $tb = Test::Builder::NoOutput->create;
    $tb->no_header(1);
    is $tb->read, '';

    $tb->ok(1);
    is $tb->read, "ok 1\n";

    $tb->done_testing(1);
    is $tb->read, "1..1\n", "no_header does not supress plan at end";
}

done_testing;
