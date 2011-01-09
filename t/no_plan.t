#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }
plan tests => 10;

use Test::Builder::NoOutput;

{
    my $tb = Test::Builder::NoOutput->create;

    ok !eval { $tb->plan(tests => undef) };
    is $@, sprintf "Got an undefined number of tests at %s line %d.\n", __FILE__, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $tb = Test::Builder::NoOutput->create;

    ok !eval { $tb->plan(tests => 0) };
    is $@, sprintf "You said to run 0 tests at %s line %d.\n", __FILE__, __LINE__ - 1;
    is $tb->read, "";
}

{
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join '', @_ };

    my $tb = Test::Builder::NoOutput->create;

    ok $tb->plan(no_plan => 1);
    is $warning, sprintf "no_plan takes no arguments at %s line %d.\n", __FILE__, __LINE__ - 1;
    is $tb->has_plan, 'no_plan';
    is $tb->read, "TAP version 13\n";
}
