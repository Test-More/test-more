#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

# Normalize the output whether we're running under Test::Harness or not.
local $ENV{HARNESS_ACTIVE} = 0;

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

{
    my $tb = Test::Builder::NoOutput->create;

    $tb->plan( tests => 1 );

#line 28
    $tb->ok(0);
    $tb->_ending;

    is($tb->read('out'), <<OUT);
TAP version 13
1..1
not ok 1
OUT

    is($tb->read('err'), <<ERR);
#   Failed test at $0 line 28.
# 1 test of 1 failed.
ERR

    done_testing(2);
}
