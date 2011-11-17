#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Formatter::TAP;

my $formatter;
sub setup {
    $formatter = TB2::Formatter::TAP->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
    isa_ok $formatter, "TB2::Formatter::TAP";

    return $formatter;
}

sub last_output {
    $formatter->streamer->read('out');
}

sub last_error {
    $formatter->streamer->read('err');
}

note "no indent"; {
    setup();

    $formatter->out("First line\nSecond line\n");
    is last_output, "First line\nSecond line\n";

    $formatter->err("First line\nSecond line\n");
    is last_error, "First line\nSecond line\n";
}


note "with indent"; {
    setup();
    $formatter->indent("    ");

    $formatter->out("First line\nSecond line\n");
    is last_output, "    First line\n    Second line\n";

    $formatter->err("First line\nSecond line\n");
    is last_error, "    First line\n    Second line\n";

    $formatter->out("First line\nSecond line");
    is last_output, "    First line\n    Second line", "no trailing newline";

    $formatter->out("First line", "\nSecond line");
    is last_output, "    First line\n    Second line", "multiple args";
}


done_testing;
