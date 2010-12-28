#!/usr/bin/perl -w

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }
plan tests => 10;

use Test::Builder::NoOutput;

{
    my $tb = Test::Builder::NoOutput->create;

#line 20
    ok !eval { $tb->plan(tests => undef) };
    is($@, "Got an undefined number of tests at $0 line 20.\n");
    is $tb->read, "TAP version 13\n";
}

{
    my $tb = Test::Builder::NoOutput->create;

#line 24
    ok !eval { $tb->plan(tests => 0) };
    is($@, "You said to run 0 tests at $0 line 24.\n");
    is $tb->read, "TAP version 13\n";
}

{
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join '', @_ };

    my $tb = Test::Builder::NoOutput->create;

#line 31
    ok $tb->plan(no_plan => 1);
    is( $warning, "no_plan takes no arguments at $0 line 31.\n" );
    is $tb->has_plan, 'no_plan';
    is $tb->read, "TAP version 13\n";
}
