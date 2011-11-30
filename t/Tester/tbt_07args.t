#!/usr/bin/perl -w

use strict;

BEGIN {
    # Don't interfere with Test::More;
    package MyTest;
    require "t/test.pl";
    plan( tests => 10 );
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
# Actual meta tests
####################################################################

# set up the outer wrapper again
Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect(out => "ok 1 - bar");

# set up what the inner wrapper expects
test_out("ok 1 - foo");

# the actual test function that we are testing
ok("1","foo");

# test the name
test_test(name => "bar");

# check that passed
my_test_test("meta test name");

####################################################################

# set up the outer wrapper again
Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect( out => "ok 1 - bar");

# set up what the inner wrapper expects
test_out("ok 1 - foo");

# the actual test function that we are testing
ok("1","foo");

# test the name
test_test(title => "bar");

# check that passed
my_test_test("meta test title");

####################################################################

# set up the outer wrapper again
Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect( out => "ok 1 - bar");

# set up what the inner wrapper expects
test_out("ok 1 - foo");

# the actual test function that we are testing
ok("1","foo");

# test the name
test_test(label => "bar");

# check that passed
my_test_test("meta test title");

####################################################################

# set up the outer wrapper again
Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect( out => "ok 1 - bar");

# set up what the inner wrapper expects
test_out("not ok 1 - foo this is wrong");
test_fail(+3);

# the actual test function that we are testing
ok("0","foo");

# test that we got what we expect, ignoring our is wrong
test_test(skip_out => 1, name => "bar");

# check that that passed
my_test_test("meta test skip_out");

####################################################################

# set up the outer wrapper again
Test::Builder::Tester::_start_testing();
$CLASS->_streamer->expect( out => "ok 1 - bar");

# set up what the inner wrapper expects
test_out("not ok 1 - foo");
test_err("this is wrong");

# the actual test function that we are testing
ok("0","foo");

# test that we got what we expect, ignoring err is wrong
test_test(skip_err => 1, name => "bar");

# diagnostics failing out
# check that that passed
my_test_test("meta test skip_err");

####################################################################
