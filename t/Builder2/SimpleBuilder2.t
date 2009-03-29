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

{
    my $result = $builder->ok(0, "should fail, and add diagnostics");
    if(!$result->passed)
    {
        $result->diagnostic("we really made a fine mess this time");
    }
    is($result->diagnostic, "we really made a fine mess this time", 
            "diagnostic check");
    $result = undef;
    is($builder->output->read, "not ok 3 - should fail, and add diagnostics\n", 
            'diagnostic output');
}


TODO: {
    local $TODO = "implement todo";
    # FIXME: shouldn't fail.
    #
    # currently the code needs changing to support this
    # syntax
    # since we have the 'Todo' as a seperate type.
    # unless we go changing types on the fly
    eval {
        $builder->ok(0, "some test")->todo("test todo feature");
    };
    is($builder->output->read, "not ok 4 # test todo feature\n");
}

done_testing();

