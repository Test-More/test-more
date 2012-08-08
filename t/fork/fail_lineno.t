#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 2, coordinate_forks => 1;
use File::Temp qw/tempfile/;

local $ENV{LANG} = "C";

my $out = do {
    open my $fh, ">", \my $out or die $!;
    my $test = Test::Builder->create();
    $test->output($fh);
    $test->failure_output($fh);
    $test->todo_output($fh);
    $test->ok(0);
    $out;
};

unlike($out, qr{lib/Test/});
like($out, qr{\Q$0\E line @{[ __LINE__ - 5 ]}\.});
