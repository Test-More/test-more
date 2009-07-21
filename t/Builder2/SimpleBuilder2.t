#!/usr/bin/perl -w

use strict;
use Test::Builder2;
use Test::Builder2::Result;
use lib 't/lib';

use Test::More;

my $builder = new_ok("Test::Builder2");
$builder->formatter->trap_output;

{
    $builder->plan(tests => 3);
    is($builder->formatter->read, "TAP version 13\n1..3\n", 'Simple builder output');
}

{
    $builder->ok(1, "test");
    is($builder->formatter->read, "ok 1 - test\n", 'test output');
}

{
    $builder->ok(0, "should fail");
    is($builder->formatter->read, "not ok 2 - should fail\n", 'failure output');
}

{
    my $result = $builder->ok(0, "should fail, and add diagnostics");
    if($result->is_fail)
    {
        $result->diagnostic("we really made a fine mess this time");
    }
    is($result->diagnostic, "we really made a fine mess this time", 
            "diagnostic check");
    $result = undef;
    is($builder->formatter->read, "not ok 3 - should fail, and add diagnostics\n", 
            'diagnostic output');
}


# Test that the error message from a missing ResultWrapper method dies
# from the perspective of the caller and as if it were a Result
{
    my $ok = $builder->ok(0, "foo");
    $builder->formatter->read;     # flush the buffer to not screw up later tests

#line 49
    ok !eval {
        $ok->i_do_not_exist;
    };
    like $@, qr{^Can't locate object method "i_do_not_exist" via package "Test::Builder2::Result.*?" at \Q$0 line 50.\E\n$};
}


# ResultWrapper should look and act like a Result subclass.
{
    my $ok = $builder->ok(0);

    isa_ok $ok, "Test::Builder2::Result";
    can_ok $ok, "is_fail";
    can_ok $ok, "diagnostic";
}

# check destructor called in correct place
{
    $builder->formatter->read;     # flush the buffer 
    # FIXME: skip should alter output
    {
        # this convoluted set of nesting ensures that if
        # we aren't returning back the wrapper after each
        # accessor we will end up destroying the wrapper
        # at the wrong point and the output will be displayed
        # before the information has been associated
        # with the result.
        my $result;
        {
            $result = $builder->ok(1)->name('skippy');
            ok $result, "Check destructor";
        }

        $result->name('please');
        ok $result, "Check destructor";
    }
    is($builder->formatter->read, "ok 6 - please\n");     # flush the buffer 
}

{
    $builder->formatter->read;     # flush the buffer 
    $builder->ok(0, "some test")->todo("test todo feature");
    is($builder->formatter->read, "not ok 7 - some test # TODO test todo feature\n");
}

done_testing();

