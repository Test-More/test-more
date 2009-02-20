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
use warnings;

use Test::More tests => 2;

{
    my $tb = Test::More->builder;

    my $out = '';
    my $err = '';
    $tb->output        (\$out);
    $tb->failure_output(\$err);

    note("foo");

    $tb->reset_outputs;

    is $out, "# foo\n";
    is $err, '';
}

