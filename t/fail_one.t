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


use Test::Builder;
my $tb = Test::Builder->create;
my($out, $err);
$tb->output(\$out);
$tb->failure_output(\$err);

$tb->plan( tests => 1 );

#line 28
$tb->ok(0);
$tb->_ending;


{
    my $Test = Test::Builder->new;

    $Test->is_eq($out, <<OUT);
1..1
not ok 1
OUT

    $Test->is_eq($err, <<ERR);
#   Failed test at $0 line 28.
# Looks like you failed 1 test of 1.
ERR

    $Test->done_testing(2);
}
