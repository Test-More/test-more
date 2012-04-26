#!/usr/bin/env perl -w

use strict;
use warnings;

use Test::Builder::Tester tests => 1, import => [':DEFAULT', 'change_formatter_class'];
use Test::More;

note "change_formatter_class"; {
    change_formatter_class("TB2::Formatter::TAP");

    test_out("ok 1");
    ok(1, "");
    test_test("using the new formatter");
}
