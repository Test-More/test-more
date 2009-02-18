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

use Test::More;

my $Test = Test::Builder->create;
my $tb = Test::More->builder;

my $out = '';
my $err = '';
$tb->output(\$out);
$tb->failure_output(\$err);

plan 'skip_all';

END {
    $Test->is_eq($out, "1..0\n");
    $Test->is_eq($err, "");
}
