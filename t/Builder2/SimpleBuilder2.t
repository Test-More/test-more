#!/usr/bin/perl -w

use strict;
use Test::Builder2;
use Test::Builder2::Result;
use lib 't/lib';

use Test::More;

my $builder = new_ok("Test::Builder2");
$builder->output->trap_output;

{
    $builder->plan(tests => 3);
    is($builder->output->read, "TAP version 13\n1..3\n", 'Simple builder output');
}

{
    $builder->ok(1, "test");
    is($builder->output->read, "ok 1 - test\n", 'test output');
}

{
    $builder->ok(0, "should fail");
    is($builder->output->read, "not ok 2 - should fail\n", 'failure output');
}


done_testing();

