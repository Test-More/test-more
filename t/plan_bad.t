#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

{
    my $tb = Test::Builder::NoOutput->create;

    ok !eval { $tb->plan( tests => 'no_plan' ); };
    is $@, sprintf "Number of tests must be a positive integer.  You gave it 'no_plan' at %s line %d.\n", $0, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $tb = Test::Builder::NoOutput->create;

    my $foo = [];
    my @foo = ($foo, 2, 3);
    ok !eval { $tb->plan( tests => @foo ) };
    is $@, sprintf "Number of tests must be a positive integer.  You gave it '$foo' at %s line %d.\n", $0, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $tb = Test::Builder::NoOutput->create;
    ok !eval { $tb->plan( tests => 9.99 ) };
    is $@, sprintf "Number of tests must be a positive integer.  You gave it '9.99' at %s line %d.\n", $0, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $tb = Test::Builder::NoOutput->create;

    ok !eval { $tb->plan( tests => -1 ) };
    is $@, sprintf "Number of tests must be a positive integer.  You gave it '-1' at %s line %d.\n", $0, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $tb = Test::Builder::NoOutput->create;

    ok !eval { $tb->plan( tests => '' ) };
    is $@, sprintf "You said to run 0 tests at %s line %d.\n", $0, __LINE__ - 1;
    is $tb->read, "";
}


{
    my $tb = Test::Builder::NoOutput->create;
#line 33
    ok !eval { $tb->plan( 'wibble' ) };
    is $@, "plan() doesn't understand wibble at $0 line 33.\n";
    is $tb->read, "";
}


done_testing;
