#!/usr/bin/perl

use Test::Builder::Tester tests => 6;
use Test::More;

ok(1,"This is a basic test");

test_out("ok 1 - tested");
ok(1,"tested");
test_test("captured okay on basic");

test_out("ok 1 - tested");
ok(1,"tested");
test_test("captured okay again without changing number");

ok(1,"test unrelated to Test::Builder::Tester");

test_out("ok 1 - one");
test_out("ok 2 - two");
ok(1,"one");
ok(2,"two");
test_test("multiple tests");

test_out("not ok 1 - should fail");
test_err("#     Failed test ($0 at line 28)");
test_err("#          got: 'foo'");
test_err("#     expected: 'bar'");
is("foo","bar","should fail");
test_test("testing failing");




