#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use strict;

BEGIN { $| = 1; $^W = 1; }

use Test::Simple tests => 4;

ok(1, 'compile');

ok(1);
ok(1, 'foo');


# Test the prototype of ok()
{
    my @foo = qw(0 0 0);
    ok @foo, "ok has a scalar prototype";
}
