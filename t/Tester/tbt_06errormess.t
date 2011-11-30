#!/usr/bin/perl -w

use strict;

BEGIN {
    # Don't interfere with Test::More;
    package MyTest;
    require "t/test.pl";
    plan( tests => 8 );
}

use Test::More;

my $CLASS = 'Test::Builder::Tester';
use Test::Builder::Tester;

my $formatter = Test::More->builder->formatter;
$formatter->streamer( $CLASS->_streamer );

sub my_test_test {
    my $name = shift;

    local $MyTest::Level = $MyTest::Level + 1;
    MyTest::ok( $CLASS->_streamer->check("out"), "STDOUT $name");
    MyTest::ok( $CLASS->_streamer->check("err"), "STDERR $name");

    $CLASS->_streamer->clear;
}

####################################################################
# Meta meta tests
####################################################################

Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect(out => "ok 1 - foo");
pass("foo");
my_test_test("basic meta meta test");

Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect(out => "not ok 1 - foo");
$CLASS->_streamer->expect(err => "#     Failed test ($0 at line ".line_num(+1).")");
fail("foo");
my_test_test("basic meta meta test 2");

Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect(out => "ok 1 - bar");
test_out("ok 1 - foo");
pass("foo");
test_test("bar");
my_test_test("meta meta test with tbt");

Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect(out => "ok 1 - bar");
test_out("not ok 1 - foo");
test_err("#     Failed test ($0 at line ".line_num(+1).")");
fail("foo");
test_test("bar");
my_test_test("meta meta test with tbt2 ");

####################################################################
