#!/usr/bin/perl -w

use strict;
use Test::Builder2::Formatter::TAP;
use Test::Builder2::Streamer::TAP; 
use Test::Builder2::Result;
use lib 't/lib';

use Test::More;

my $formatter;
sub new_formatter {
    $formatter = new_ok(
        "Test::Builder2::Formatter::TAP",
        [ streamer_class => 'Test::Builder2::Streamer::Debug' ]
    );
}

sub last_output {
  $formatter->streamer->read('out');
}

# Test the defaults
{
    my $streamer = Test::Builder2::Streamer::TAP->new; 
    is $streamer->output_fh,  *STDOUT;
    is $streamer->error_fh,   *STDERR;
}

# Test that begin does nothing with no args
{
    new_formatter;
    $formatter->begin;
    is last_output, "TAP version 13\n", "begin() with no args";
}

# Test begin
{
    new_formatter;
    $formatter->begin( tests => 99 );
    is last_output, <<'END', "begin( tests => # )";
TAP version 13
1..99
END

}

# Test end
{
    new_formatter;
    $formatter->end();
    is last_output, "", "end() does nothing";
}

# Test plan-at-end
{
    new_formatter;
    $formatter->end( tests => 42 );
    is last_output, <<END, "end( tests => # )";
1..42
END
}

# Test read
{
    new_formatter;
    $formatter->begin();
    is last_output, "TAP version 13\n", "check all stream";
}

# test skipping
{
    new_formatter;
    $formatter->begin(skip_all=>"bored already");
    is last_output, "TAP version 13\n1..0 # skip bored already", "skip_all";
}

# no plan
{
    new_formatter;
    $formatter->begin(no_plan => 1);
    is last_output, "TAP version 13\n", "no_plan";
}


# Test >1 pair of args
{
    new_formatter;
    ok(!eval {
        $formatter->end( tests => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more args";
}

# more params and no right one
{
    new_formatter;
    ok(!eval {
        $formatter->end( test => 32, moredata => 1 );
    });
    like $@, qr/\Qend() takes only one pair of arguments/, "more and wrong args";
}

# wrong param
{
    new_formatter;
    ok(!eval {
        $formatter->end( test => 32 );
    });
    like $@, qr/\QUnknown argument test to end()/, "wrong args";
}


# Fail, no description
{
    my $result = Test::Builder2::Result->new_result( pass => 0 );
    $result->test_number(1);
    $formatter->result($result);
    is(last_output, "not ok 1\n", "testing not okay");
}

# Pass, no description
{
    my $result = Test::Builder2::Result->new_result( pass => 1 );
    $result->test_number(2);
    $formatter->result($result);
    is(last_output, "ok 2\n", "testing okay");
}

# TODO fail, no description
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
        directives      => [qw(todo)],
        reason          => "reason" 
    );
    $result->test_number(3);
    $formatter->result($result);
    is(last_output, "not ok 3 # TODO reason\n", "testing todo");
}

# TODO pass, no description
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(todo)],
        reason          => "reason"
    );
    $result->test_number(4);
    $formatter->result($result);
    is(last_output, "ok 4 # TODO reason\n", "testing todo");
}

# TODO pass, with description
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(todo)],
        reason          => "reason"
    );
    $result->test_number(4);
    $result->description('a fine test');
    $formatter->result($result);
    is(last_output, "ok 4 - a fine test # TODO reason\n", "testing todo");
}

# Fail with dashed description
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
    );
    $result->description(' - a royal pain');
    $result->test_number(6);
    $formatter->result($result);
    is(last_output, "not ok 6 -  - a royal pain\n", "test description");
}

# Skip fail
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 0,
        directives      => [qw(skip)],
    );
    $result->description('skip test');
    $result->test_number(7);
    $result->reason('Not gonna work');
    $formatter->result($result);

    is(last_output, "not ok 7 - skip test # SKIP Not gonna work\n", "skip fail");
}

# Skip pass
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
    );
    $result->description('skip test');
    $result->test_number(8);
    $result->reason('Because');
    $formatter->result($result);

    is(last_output, "ok 8 - skip test # SKIP Because\n", "skip pass");
}


# No number
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1
    );
    $formatter->result($result);

    is(last_output, "ok\n", "pass with no number");
}


# Descriptions with newlines in them
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1
    );
    $result->test_number(5);
    $result->description("Foo\nBar\n");

    $formatter->result($result);
    is(last_output, "ok 5 - Foo\\nBar\\n\n", "description with newline");
}


# Descriptions with newlines in them
{
    my $result = Test::Builder2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        test_number     => 4,
        reason          => "\nFoo\nBar\n",
    );

    $formatter->result($result);
    is(last_output, "ok 4 # SKIP \\nFoo\\nBar\\n\n", "reason with newline");
}


done_testing();
