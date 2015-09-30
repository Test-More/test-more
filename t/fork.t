#!/usr/bin/perl -w
use strict;
use warnings;
use Test::Stream 'CanFork';

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;
plan tests => 1;

if( fork ) { # parent
    pass("Only the parent should process the ending, not the child");
}
else {
    exit;   # child
}

