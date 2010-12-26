#!/usr/bin/perl

# Test Streamer::Print

use strict;
use warnings;

use Test::Builder2::Streamer::Print;

my $print = Test::Builder2::Streamer::Print->new;

$print->write(out => "1..3\n", "ok 1 - write\n");

$print->safe_print( $print->output_fh, "ok 2 - safe_print\n" );

# Make sure it ignores globals
{
    local $\ = "not ok";
    local $" = "not ok";
    local $, = "not ok";

    $print->safe_print( $print->output_fh, "ok 3 - safe_print ignores globals\n" );
}
