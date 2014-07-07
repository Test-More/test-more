#!/usr/bin/perl

use Test::More;

BEGIN {
	eval "qr//" or plan skip_all => "no qr// support";
	plan tests => 12;
}

use Test::Builder::Tester;

########################################################################
# basic checks
########################################################################

# regular expressions with test_err and test_out

test_out("/ok 1\\s+-\\s+a+b\\n/");
ok(1,"aaaab");
test_test("basic regex test test_out");

test_out("/ok 1 -/","/\\s+a+b/","c");
ok(1,"aaaabc");
test_test("multiple regex test test_out");

test_out("/ok 1 -/","/\\s+a+b/","c");
ok(1,"aaaabc");
test_test("multiple regex test test_out");

test_out(["ok 1 -"],"/\\s+a+b/","c");
ok(1,"aaaabc");
test_test("multiple str test test_out");

test_err("/#\\s+a+b\\n/");
diag("aaaaab");
test_test("basic regex test test_err");

# regular expressions with test_diag

test_diag("/a+b\\n/");
diag("aaaaab");
test_test("basic regex test test_diag");

########################################################################
# examples from the documentation
########################################################################

test_out('/not ok [0-9]+ - (.*)\n/');
test_fail(+2);
test_diag(qr/fo+\n/);
ok(0,"oh no");
diag("foo");
test_test("documentation example 1");

test_diag(
 ["The value ", qr/[0-9]+/, " is too high.","\n"],
 "Expected a value below 10.",
);
diag("The value 100 is too high.");
diag("Expected a value below 10.");
test_test("documentation example 2");

########################################################################
# this checks backwards compatibility with test written for the old
# version of Test::Builder::Tester, i.e. to check that accidentally
# possible syntax for regex check that we're now explictly supporting
# is still possible.
########################################################################

test_out(qr/ok 1 - foo/,"");
ok(1,"foo");
test_test("single qr regex");

test_out(qr/ok 1 - /,qr/foo/,"");
ok(1,"foo");
test_test("multiple qr regex");

test_out("not ok 1 - foo");
test_fail(+2);
test_err(qr/# zang\n/);
ok(0,"foo");
diag("zang");
test_test("failure followed by regex");

test_out("not ok 1 - foo");
test_fail(+3);
test_out("not ok 2 - bar");
test_fail(+2);
ok(0,"foo");
ok(0,"bar");
test_test("multiple failures with one test_test");