#!/usr/bin/perl -w
# $Id$

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::More tests => 8;

my $tb = Test::Builder->create;
$tb->level(0);

#line 19
ok !eval { $tb->plan(tests => undef) };
is($@, "Got an undefined number of tests at $0 line 19.\n");

#line 23
ok !eval { $tb->plan(tests => 0) };
is($@, "You said to run 0 tests at $0 line 23.\n");

#line 27
ok !eval { $tb->ok(1) };
is( $@, "You tried to run a test without a plan at $0 line 27.\n");

#line 31
ok !eval { $tb->plan(no_plan => 1) };
is( $@, "no_plan takes no arguments at $0 line 31.\n" );
