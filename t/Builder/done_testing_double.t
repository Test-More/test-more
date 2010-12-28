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
    like $@, qr/^\Qdone_testing() called twice/, "done_testing twice error message";
    like $@, qr/\n\s+First at \Q$0\E line 24/,   "  part 2";
    like $@, qr/\n\s+then  at \Q$0\E line 25/,   "  part 3";
}

is($tb->read, <<"END", "multiple done_testing");
TAP version 13
ok 1
ok 2
ok 3
1..3
END

done_testing;
