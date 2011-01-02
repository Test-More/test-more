#!/usr/bin/perl -w

# Test what happens when no plan is declared and done_testing() is not seen

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;
my $tb = Test::Builder::NoOutput->create;

{
    $tb->level(0);
    $tb->ok(1, "just a test");
    $tb->ok(1, "  and another");
    $tb->_ending;
}

is($tb->read, <<'END', "proper behavior when no plan is seen");
TAP version 13
ok 1 - just a test
ok 2 -   and another
# 2 tests ran, but no plan was declared.
END

done_testing;
