#!/usr/bin/env perl -w

use strict;
use warnings;

use Test::Builder::Tester tests => 1, import => ['change_formatter_class', ':DEFAULT'];
use Test::More;

note "change_formatter_class"; {
    change_formatter_class("TB2::Formatter::TAP");

    test_out("TAP version 13");
    test_out("1..2");
    plan tests => 2;
    test_test("using the new formatter");
}
