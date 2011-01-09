#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Builder2::Events;
use Test::Builder2::Formatter::TAP;


my $formatter;
sub new_formatter {
    $formatter = Test::Builder2::Formatter::TAP->create(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "Test::Builder2::Formatter::TAP";

    return $formatter;
}

sub last_output {
    $formatter->streamer->read('out');
}


note "Escape # in test name"; {
    new_formatter;

    my $result = Test::Builder2::Result->new_result(
        pass => 1, description => "foo # bar"
    );

    $formatter->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    last_output;

    $formatter->accept_result($result);

    is last_output, "ok 1 - foo \\# bar\n";
}


note "Escape # in directive description"; {
    new_formatter;

    my $result = Test::Builder2::Result->new_result(
        pass => 1, description => "foo # bar", directives => ['todo'], reason => "this # that"
    );

    $formatter->accept_event(
        Test::Builder2::Event::StreamStart->new
    );
    last_output;

    $formatter->accept_result($result);

    is last_output, "ok 1 - foo \\# bar # TODO this \\# that\n";
}


done_testing;
