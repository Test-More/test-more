#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::EventCoordinator;
use TB2::Events;
use TB2::Formatter::TAP;
use TB2::Streamer::Debug;

my $formatter;
my $ec;
sub new_formatter {
    $formatter = TB2::Formatter::TAP->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
    isa_ok $formatter, "TB2::Formatter::TAP";

    my $ec = TB2::EventCoordinator->new(
        formatters => [$formatter],
    );

    return $ec;
}

sub last_output {
    $formatter->streamer->read('out');
}

sub last_error {
    $formatter->streamer->read('err');
}

sub clear_formatter {
    # each output stream, including "all", has its own position
    $formatter->streamer->read($_) for ('out', 'err', undef);
}

sub all_output {
    $formatter->streamer->read;
}

my $TestEnd   = TB2::Event::TestEnd->new;
my $Pass        = TB2::Result->new_result( pass => 1 );
my $Fail        = TB2::Result->new_result( pass => 0 );

note "Good test"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is all_output, '',          "good test, no output";
}


note "No plan, no results"; {
    my $ec = new_formatter;

    clear_formatter;

    $ec->post_event( $TestEnd );
    is all_output, "TAP version 13\n",          "no plan, no results, no output";
}


note "Single failure, all failed"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( $Fail );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 1 test of 1 failed.
OUT
}


note "Single failure, some passed"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 3 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 1 test of 3 failed.
OUT
}


note "Many failures, some passed"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 5 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 2 tests of 5 failed.
OUT
}


note "Many failures, some passed, no_plan"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( no_plan => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, "1..5\n";
    is last_error, <<OUT,          "ending commentary";
# 2 tests of 5 failed.
OUT
}


note "Many failures, some passed, done_testing with expected"; {
    my $ec = new_formatter;

    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 5 ) );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, "1..5\n";
    is last_error, <<OUT,          "ending commentary";
# 2 tests of 5 failed.
OUT
}


note "Many failures, some passed, done_testing with no plan"; {
    my $ec = new_formatter;

    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    $ec->post_event( TB2::Event::SetPlan->new( no_plan => 1 ) );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, "1..5\n";
    is last_error, <<OUT,          "ending commentary";
# 2 tests of 5 failed.
OUT
}


note "Passing test with no plan"; {
    my $ec = new_formatter;

    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 1 test ran, but no plan was declared.
OUT
}


note "Passing tests with no plan"; {
    my $ec = new_formatter;

    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 3 tests ran, but no plan was declared.
OUT
}


note "Failing tests with no plan"; {
    my $ec = new_formatter;

    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 3 tests ran, but no plan was declared.
# 1 test of 3 failed.
OUT
}


note "All passed, too few"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 3 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 3 tests planned, but 2 ran.
OUT
}


note "All passed, too many"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 1 test planned, but 2 ran.
OUT
}


note "Some failed, too many"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# 1 test planned, but 2 ran.
# 1 test of 2 failed.
OUT
}


note "Skipped test, no results"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( skip => 1 ) );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is all_output, '',  "skipped test, no output";
}


note "Skipped test, one result"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( skip => 1 ) );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# The test was skipped, but 1 test ran.
OUT
}


note "Skipped test, two results"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( skip => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# The test was skipped, but 2 tests ran.
OUT
}


note "Skipped test, with failures"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::SetPlan->new( skip => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is last_output, '';
    is last_error, <<OUT,          "ending commentary";
# The test was skipped, but 3 tests ran.
# 1 test of 3 failed.
OUT
}


note "no ending commentary"; {
    my $ec = new_formatter;
    $ec->formatters->[0]->show_ending_commentary(0);

    $ec->post_event( TB2::Event::SetPlan->new( skip => 1 ) );
    $ec->post_event( $Pass );
    $ec->post_event( $Pass );
    $ec->post_event( $Fail );
    clear_formatter;

    $ec->post_event( $TestEnd );
    is all_output, '';
}


done_testing;
