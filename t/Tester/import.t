#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

note "default import"; {
    package Foo1;
    use Test::Builder::Tester;

    ::ok !defined &color;
    ::ok defined &test_test;
    ::ok defined &test_out;
}


note "optional import"; {
    package Foo2;
    use Test::Builder::Tester import => ['color'];

    ::ok defined &color;
    ::ok !defined &test_test;
    ::ok !defined &test_out;
}


note "default import"; {
    package Foo3;
    use Test::Builder::Tester import => [':DEFAULT', 'color'];

    ::ok defined &color;
    ::ok defined &test_test;
    ::ok defined &test_out;
}


note "deny import"; {
    package Foo4;
    use Test::Builder::Tester import => ['!test_test'];

    ::ok !defined &color;
    ::ok !defined &test_test;
    ::ok defined &test_out;
}


done_testing;
