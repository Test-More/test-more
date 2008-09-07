#!/usr/bin/perl -w
# $Id: /mirror/googlecode/test-more/t/diag.t 57943 2008-08-18T02:09:22.275428Z brooklyn.kid51  $

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

use TieOut;

use Test::More tests => 2;

{
    my $test = Test::More->builder;

    my $output          = tie *FAKEOUT, "TieOut";
    my $fail_output     = tie *FAKEERR, "TieOut";
    $test->output        (*FAKEOUT);
    $test->failure_output(*FAKEERR);

    note("foo");

    $test->reset_outputs;

    is $output->read,      "# foo\n";
    is $fail_output->read, '';
}

