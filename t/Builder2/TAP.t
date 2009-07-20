#!/usr/bin/perl -w

use strict;
use Test::Builder2::Formatter::TAP;
use Test::Builder2::Result;
use lib 't/lib';

use Test::More;

my $formatter = new_ok("Test::Builder2::Formatter::TAP");

# Test the defaults
{
    is $formatter->output_fh,  *STDOUT;
    is $formatter->failure_fh, *STDERR;
    is $formatter->error_fh,   *STDERR;
}

$formatter->trap_output;

# Test that begin does nothing with no args
{
    $formatter->begin;
    is $formatter->read, "TAP version 13\n", "begin() with no args";
}

# Test begin
{
    $formatter->begin( tests => 99 );
    is $formatter->read, <<'END', "begin( tests => # )";
TAP version 13
1..99
END

}

# Test end
{
    $formatter->end();
    is $formatter->read, "", "end() does nothing";

    $formatter->end( tests => 42 );
    is $formatter->read, <<END, "end( tests => # )";
1..42
END
}

# Test read
{
    $formatter->begin();
    is $formatter->read('all'), "TAP version 13\n", "check all stream";
}

# Test read out
{
    $formatter->begin();
    is $formatter->read('out'), "TAP version 13\n", "check out stream";
}

# Test read err
{
    $formatter->begin();
    is $formatter->read('err'), "", "check err stream";
    $formatter->read; # clear the buffer
}

# Test read todo
{
    $formatter->begin();
    is $formatter->read('todo'), "", "check todo stream";
    $formatter->read; # clear the buffer
}

# test skipping
{
    $formatter->begin(skip_all=>"bored already");
    is $formatter->read, "TAP version 13\n1..0 # skip bored already", "skip_all";
}

# no plan
{
    $formatter->begin(no_plan => 1);
    is $formatter->read, "TAP version 13\n", "no_plan";
}


# Test >1 pair of args
{
    ok(!eval {
        $formatter->end( tests => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more args";
}

# more params and no right one
{
    ok(!eval {
        $formatter->end( test => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more and wrong args";
}

# wrong param
{
    ok(!eval {
        $formatter->end( test => 32 );
    });
    like $@, qr/\QUnknown argument test to end()/, "wrong args";
}

# result testing.
{
    my $result = Test::Builder2::Result->new( type => 'fail' );
    $result->test_number(1);
    $result->description('');
    $formatter->result($result);
    is($formatter->read, "not ok 1\n", "testing not okay");
}

{
    my $result = Test::Builder2::Result->new( type => 'pass' );
    $result->test_number(2);
    $result->description('');
    $formatter->result($result);
    is($formatter->read, "ok 2\n", "testing okay");
}

{
    my $result = Test::Builder2::Result->new( type => 'todo_fail', reason => "reason" );
    $result->test_number(3);
    $result->description('');
    $formatter->result($result);
    is($formatter->read, "not ok 3 # TODO reason\n", "testing todo");
}

{
    my $result = Test::Builder2::Result->new( type => 'todo_pass', reason => "reason" );
    $result->test_number(4);
    $result->description('');
    $formatter->result($result);
    is($formatter->read, "ok 4 # TODO reason\n", "testing todo");
}

{
    my $result = Test::Builder2::Result->new( type => 'todo', reason => "reason" );
    $result->test_number(4);
    $result->description('a fine test');
    $formatter->result($result);
    is($formatter->read, "ok 4 - a fine test # TODO reason\n", "testing todo");
}

{
    my $result = Test::Builder2::Result->new( type => 'fail' );
    $result->description('');
    $result->test_number(1);
    $formatter->result($result);
    is($formatter->read, "not ok 1\n", "testing not okay");
}

{
    my $result = Test::Builder2::Result->new( type => 'fail' );
    $result->description(' - a royal pain');
    $result->test_number(6);
    $formatter->result($result);
    is($formatter->read, "not ok 6 -  - a royal pain\n", "test description");
}

SKIP: {
    my $result = Test::Builder2::Result->new( type => 'fail' );
    $result->description('skip test');
    $result->test_number(7);
    $result->skip('Not gonna work');
    $formatter->result($result);

    skip 'Skip output not done yet', 1;
    is($formatter->read, "not ok 7 - skip test # skip Not gonna work\n", "test description");
}

done_testing();
