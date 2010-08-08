#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Builder2::AssertRecord;
use Test::Builder2::AssertStack;

{
    note("A fresh stack");
    my $stack = new_ok "Test::Builder2::AssertStack";
    is_deeply $stack->asserts, [];
    is $stack->top, undef;
    ok !$stack->at_top;
    ok !$stack->in_assert;

    note("Push on one assert");
    my $foo = new_ok "Test::Builder2::AssertRecord", [{
        package         => "Foo",
        filename        => "foo.t",
        line            => 23,
        subroutine      => "foo"
    }];
    $stack->push($foo);
    is $stack->from_top("This ", "and"), "This and at foo.t line 23";
    ok $stack->at_top;
    ok $stack->in_assert;

    note("Push on another");
    my $bar = new_ok "Test::Builder2::AssertRecord", [{
        package         => "Bar",
        filename        => "bar.t",
        line            =>  42,
        subroutine      => "bar"
    }];
    $stack->push($bar);
    is $stack->from_top("Wibble"), "Wibble at foo.t line 23", "from_top still from the top";
    ok !$stack->at_top;
    ok $stack->in_assert;

    note("Pop it off");
    is_deeply $stack->pop, $bar;
    is $stack->from_top("This ", "and"), "This and at foo.t line 23";
    ok $stack->at_top;
    ok $stack->in_assert;

    note("Pop off the last one");
    is_deeply $stack->pop, $foo;
    ok !eval { $stack->from_top("This ", "and") }, "from_top asserts when there's no asserts";
    ok !$stack->at_top;
    ok !$stack->in_assert;

    # Try to pop one too many
    ok !eval { $stack->pop }, "asserts when popping off one too many";
}

done_testing;
