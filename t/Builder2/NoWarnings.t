#!/usr/bin/perl

# Test the NoWarnings example

use strict;
use warnings;

BEGIN { require "t/test.pl" }

# Simulate running a test with NoWarnings
{
    require Test::Builder2::Streamer::Debug;
    require Test::Builder2;
    my $builder = Test::Builder2->singleton;
    $builder->formatter->streamer(Test::Builder2::Streamer::Debug->new);


    # Turn on no warnings, but silence them so we don't mess up the test output
    use lib 'examples/TB2/lib/';
    require TB2::NoWarnings;
    TB2::NoWarnings::no_warnings( quiet_warnings => 1 );


    # Here's the test
    $builder->stream_start();
    $builder->set_plan(
        tests       => 2
    );
    $builder->ok(1, "pass 1");
    warn "Wibble";
    $builder->ok(1, "pass 2");
    $builder->stream_end();


    # Test the result
    plan tests => 2;
    like $builder->formatter->streamer->read("out"), qr/^1..3$/m, "count correct";
    ok $builder->history->results->[2], "no warnings test failed properly";
}
