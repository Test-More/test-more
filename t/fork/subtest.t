#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN {
    package MyTest;
    require "t/test.pl";
    plan( skip_all => "test needs fork()" ) unless has_fork();
}

use Test::More tests => 1;
use App::Prove;

TODO: {
    local $TODO = 'subtest is not supported yet';
    my $prove = App::Prove->new();
    $prove->process_args('-Ilib', 't/fork/nest/subtest.ttt');
    ok(!$prove->run(), 'this test should fail');
};


