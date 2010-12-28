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

BEGIN {
    package Test;
    require 't/test.pl';
    Test::plan( tests => 2 );
}

use Test::More;

my $out = '';
my $err = '';
{
    my $tb = Test::More->builder;
    $tb->output(\$out);
    $tb->failure_output(\$err);

    plan 'skip_all';
}

END {
    Test::is($out, <<END);
TAP version 13
1..0 # SKIP
END

    Test::is($err, "");
}
