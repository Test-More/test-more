#!/usr/bin/perl -w
use Test::Stream::Shim;

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

use Test::More;

plan tests => 4;
eval { plan tests => 4 };
is( $@, sprintf("Tried to plan twice!\n    %s line %d\n    %s line %d\n", $0, __LINE__ - 2, $0, __LINE__ - 1),
    'disallow double plan' );
eval { plan 'no_plan'  };
is( $@, sprintf("Tried to plan twice!\n    %s line %d\n    %s line %d\n", $0, __LINE__ - 5, $0, __LINE__ - 1),
    'disallow changing plan' );

pass('Just testing plan()');
pass('Testing it some more');
