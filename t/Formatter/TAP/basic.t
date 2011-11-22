#!/usr/bin/perl -w

use strict;

use TB2::EventCoordinator;
use TB2::Formatter::TAP;
use TB2::Events;
use lib 't/lib';
BEGIN { require "t/test.pl" }

# Prevent this from messing with our formatting
local $ENV{HARNESS_ACTIVE} = 0;


my $formatter;
my $ec;
sub setup {
    $formatter = TB2::Formatter::TAP->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "TB2::Formatter::TAP";

    $ec = TB2::EventCoordinator->new(
        formatters => [$formatter],
    );

    return $ec;
}

sub last_output {
  $formatter->streamer->read('out');
}

# Test that begin does nothing with no args
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    is last_output, "TAP version 13\n", "begin() with no args";
}

# Can't have a plan outside a stream
{
    setup;
    ok !eval {
        $ec->post_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 99
            ),
        );
    };
    like $@, qr/^A plan was set but we're not testing/;
}

# Test begin
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    $ec->post_event(
        TB2::Event::SetPlan->new(
            asserts_expected => 99
        )
    );
    is last_output, <<'END', "set plan at start";
TAP version 13
1..99
END

}

# Test end
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    $ec->post_event(
        TB2::Event::SetPlan->new(
            asserts_expected => 2
        )
    );

    # Clear the buffer, all we care about is test end
    last_output;

    $ec->post_event(
        TB2::Event::TestEnd->new
    );
    is last_output, "", "empty stream does nothing";
}

# Test plan-at-end
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    my $result = TB2::Result->new_result(
        pass            => 1,
    );

    $ec->post_event( $result );

    $ec->post_event(
        TB2::Event::SetPlan->new(
            asserts_expected    => 2
        )
    );

    $ec->post_event( $result );

    $ec->post_event(
        TB2::Event::TestEnd->new
    );
    is last_output, <<END, "end( tests => # )";
TAP version 13
ok 1
ok 2
1..2
END
}

# Test read
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    is last_output, "TAP version 13\n", "check all stream";
}

# test skipping
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    $ec->post_event(
        TB2::Event::SetPlan->new(
            skip        => 1,
            skip_reason => "bored now"
        )
    );
    is last_output, "TAP version 13\n1..0 # SKIP bored now\n", "skip_all";
}

# no plan
{
    setup;
    $ec->post_event(
        TB2::Event::TestStart->new
    );
    $ec->post_event(
        TB2::Event::SetPlan->new(
            no_plan     => 1
        )
    );
    is last_output, "TAP version 13\n", "no_plan";
}


# Fail, no name
{
    my $result = TB2::Result->new_result( pass => 0 );
    $result->test_number(1);
    $ec->post_event($result);
    is(last_output, "not ok 1\n", "testing not okay");
}

# Pass, no name
{
    my $result = TB2::Result->new_result( pass => 1 );
    $result->test_number(2);
    $ec->post_event($result);
    is(last_output, "ok 2\n", "testing okay");
}

# TODO fail, no name
{
    my $result = TB2::Result->new_result(
        pass            => 0,
        directives      => [qw(todo)],
        reason          => "reason" 
    );
    $result->test_number(3);
    $ec->post_event($result);
    is(last_output, <<OUT, "testing todo fail");
not ok 3 # TODO reason
#   Failed (TODO) test.
OUT

}

# TODO pass, no name
{
    my $result = TB2::Result->new_result(
        pass            => 1,
        directives      => [qw(todo)],
        reason          => "reason"
    );
    $result->test_number(4);
    $ec->post_event($result);
    is(last_output, "ok 4 # TODO reason\n", "testing todo");
}

# TODO pass, with name
{
    my $result = TB2::Result->new_result(
        pass            => 1,
        directives      => [qw(todo)],
        reason          => "reason"
    );
    $result->test_number(4);
    $result->name('a fine test');
    $ec->post_event($result);
    is(last_output, "ok 4 - a fine test # TODO reason\n", "testing todo");
}

# Fail with dashed name
{
    my $result = TB2::Result->new_result(
        pass            => 0,
    );
    $result->name(' - a royal pain');
    $result->test_number(6);
    $ec->post_event($result);
    is(last_output, "not ok 6 -  - a royal pain\n", "test name");
}

# Skip fail
{
    my $result = TB2::Result->new_result(
        pass            => 0,
        directives      => [qw(skip)],
    );
    $result->name('skip test');
    $result->test_number(7);
    $result->reason('Not gonna work');
    $ec->post_event($result);

    is(last_output, "not ok 7 - skip test # SKIP Not gonna work\n", "skip fail");
}

# Skip pass
{
    my $result = TB2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
    );
    $result->name('skip test');
    $result->test_number(8);
    $result->reason('Because');
    $ec->post_event($result);

    is(last_output, "ok 8 - skip test # SKIP Because\n", "skip pass");
}


# No number
{
    $formatter->use_numbers(0);
    my $result = TB2::Result->new_result(
        pass            => 1
    );
    $ec->post_event($result);

    is(last_output, "ok\n", "pass with no number");
    $formatter->use_numbers(1);
}


# Names with newlines in them
{
    my $result = TB2::Result->new_result(
        pass            => 1
    );
    $result->test_number(5);
    $result->name("Foo\nBar\n");

    $ec->post_event($result);
    is(last_output, "ok 5 - Foo\\nBar\\n\n", "name with newline");
}


# Names with newlines in them
{
    my $result = TB2::Result->new_result(
        pass            => 1,
        directives      => [qw(skip)],
        test_number     => 4,
        reason          => "\nFoo\nBar\n",
    );

    $ec->post_event($result);
    is(last_output, "ok 4 # SKIP \\nFoo\\nBar\\n\n", "reason with newline");
}


note "Name with an empty string (github #84)"; {
    my $result = TB2::Result->new_result(
        pass            => 1,
        test_number     => 99,
        name            => ''
    );

    $ec->post_event($result);
    is(last_output, "ok 99\n", "empty string name");
}

done_testing();
