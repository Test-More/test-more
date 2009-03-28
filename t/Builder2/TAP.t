#!/usr/bin/perl -w

use strict;
use Test::Builder2::Output::TAP;
use lib 't/lib';

use Test::More;

my $output = new_ok("Test::Builder2::Output::TAP");

# Test the defaults
{
    is $output->output_fh,  *STDOUT;
    is $output->failure_fh, *STDERR;
    is $output->error_fh,   *STDERR;
}

$output->trap_output;

# Test that begin does nothing with no args
{
    $output->begin;
    is $output->read, "TAP version 13\n", "begin() with no args";
}

# Test begin
{
    $output->begin( tests => 99 );
    is $output->read, <<'END', "begin( tests => # )";
TAP version 13
1..99
END

}

# Test end
{
    $output->end();
    is $output->read, "", "end() does nothing";

    $output->end( tests => 42 );
    is $output->read, <<END, "end( tests => # )";
1..42
END
}

# Test read
{
    $output->begin();
    is $output->read('all'), "TAP version 13\n", "check all stream";
}

# output Test read output
{
    $output->begin();
    is $output->read('out'), "TAP version 13\n", "check out stream";
}

# output Test read output
{
    $output->begin();
    is $output->read('err'), "", "check err stream";
    $output->read; # clear the buffer
}

# output Test read output
{
    $output->begin();
    is $output->read('todo'), "", "check todo stream";
    $output->read; # clear the buffer
}

# test skipping
{
    $output->begin(skip_all=>10);
    is $output->read, "TAP version 13\n1..0 # skip 10", "skip_all";
}

# no plan
{
    $output->begin(no_plan => 1);
    is $output->read, "TAP version 13\n", "no_plan";
}


# Test >1 pair of args
{
    ok(!eval {
        $output->end( tests => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more args";
}

# more params and no right one
{
    ok(!eval {
        $output->end( test => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more and wrong args";
}

# wrong param
{
    ok(!eval {
        $output->end( test => 32 );
    });
    like $@, qr/\QUnknown argument test to end()/, "wrong args";
}

done_testing();
