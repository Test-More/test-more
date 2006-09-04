#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}


use Test::More tests => 7;
use Test::Builder;
my $tb = Test::Builder->create;
$tb->level(0);

ok !eval { $tb->plan( tests => 'no_plan' ); };
is $@, "Number of tests must be a postive integer.  You gave it 'no_plan'.\n";

my $foo = [];
my @foo = ($foo, 2, 3);
ok !eval { $tb->plan( tests => @foo ) };
is $@, "Number of tests must be a postive integer.  You gave it '$foo'.\n";

ok !eval { $tb->plan( tests => 0 ) };
ok !eval { $tb->plan( tests => -1 ) };
ok !eval { $tb->plan( tests => '' ) };
