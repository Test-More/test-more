#!/usr/bin/perl -w

use strict;
use Test::Builder2;
use Test::Builder2::Result;
use lib 't/lib';

use Test::More;

use Test::Builder2::Formatter::TAP;
my $tap = Test::Builder2::Formatter::TAP->new({
  streamer_class => 'Test::Builder2::Streamer::Debug',
});

my $builder = new_ok("Test::Builder2", [ formatter => $tap ]);

{
    $builder->stream_start(tests => 3);
    is($tap->streamer->read('out'), "TAP version 13\n1..3\n", 'Simple builder output');
}

{
    $builder->ok(1, "test");
    is($tap->streamer->read('out'), "ok 1 - test\n", 'test output');
}

{
    $builder->ok(0, "should fail");
    is($tap->streamer->read('out'), "not ok 2 - should fail\n", 'failure output');
}

{
    my $result = $builder->ok(0, "should fail, and add diagnostics");
    if($result->is_fail)
    {
        $result->diagnostic([error => "we really made a fine mess this time"]);
    }
    is_deeply($result->diagnostic, [error => "we really made a fine mess this time"], 
            "diagnostic check");
    is($tap->streamer->read('out'), "not ok 3 - should fail, and add diagnostics\n", 
            'diagnostic output');
}


# Test that the error message from a missing Result method dies
# from the perspective of the caller and as if it were a Result
{
    my $ok = $builder->ok(0, "foo");
    $tap->streamer->read('out');     # flush the buffer to not screw up later tests

#line 49
    ok !eval {
        $ok->i_do_not_exist;
    };
    like $@, qr{^Can't locate object method "i_do_not_exist" via package "Test::Builder2::Result.*?" at \Q$0 line 50.\E\n$};
}


# ok() should return a Result
{
    my $ok = $builder->ok(0);
    isa_ok $ok, "Test::Builder2::Result::Base";
}

done_testing();
