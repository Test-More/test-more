#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;

plan tests => 4;

eval { plan tests => 4 };
is( $@, sprintf("Tried to set a plan at %s line %d, but a plan was already set at %s line %d.\n", $0, __LINE__ - 1, $0, __LINE__ - 3),
    'disallow double plan' );

eval { plan 'no_plan'  };
is( $@, sprintf("Tried to set a plan at %s line %d, but a plan was already set at %s line %d.\n", $0, __LINE__ - 1, $0, __LINE__ - 7),
    'disallow changing plan' );

pass('Just testing plan()');
pass('Testing it some more');
