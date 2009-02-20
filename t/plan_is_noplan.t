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

use Test::More tests => 2;

use Test::Builder;
my $tb = Test::Builder->create;

my($out, $err) = ('', '');
{
    $tb->output(\$out);
    $tb->failure_output(\$err);

    $tb->plan('no_plan');

    $tb->ok(1, 'foo');
    $tb->_ending;
}

{
    is($out, <<OUT);
ok 1 - foo
1..1
OUT

    is($err, <<ERR);
ERR
}
