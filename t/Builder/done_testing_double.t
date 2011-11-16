#!/usr/bin/perl -w

use strict;
BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

BEGIN { require "t/test.pl" }

use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

{
    # Normalize test output
    local $ENV{HARNESS_ACTIVE};

    $tb->ok(1);
    $tb->ok(1);
    $tb->ok(1);

#line 24
    $tb->done_testing(3);
    ok !eval { $tb->done_testing; };
    is $@, "Tried to finish testing, but testing is already done at $0 line 25.\n";
}

is($tb->read, <<"END", "multiple done_testing");
TAP version 13
ok 1
ok 2
ok 3
1..3
END

done_testing;
