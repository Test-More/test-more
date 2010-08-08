#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use Test::Builder2::AssertStack;

{
    # A fresh stack
    my $stack = new_ok "Test::Builder2::AssertStack";
    is_deeply $stack->asserts, [];
    is_deeply [$stack->top], [];
    ok !$stack->at_top;
    ok !$stack->in_assert;

    # Push on one assert
    $stack->push(["Foo", "foo.t", 23]);
    is $stack->from_top("This ", "and"), "This and at foo.t line 23";
    ok $stack->at_top;
    ok $stack->in_assert;

    # Push on another
    $stack->push(["Bar", "bar.t", 23]);
    is $stack->from_top("Wibble"), "Wibble at foo.t line 23", "from_top still from the top";
    ok !$stack->at_top;
    ok $stack->in_assert;

    # Pop it off
    is_deeply $stack->pop, ["Bar", "bar.t", 23];
    is $stack->from_top("This ", "and"), "This and at foo.t line 23";
    ok $stack->at_top;
    ok $stack->in_assert;

    # Pop off the last one
    is_deeply $stack->pop, ["Foo", "foo.t", 23];
    ok !eval { $stack->from_top("This ", "and") }, "from_top asserts when there's no asserts";
    ok !$stack->at_top;
    ok !$stack->in_assert;

    # Try to pop one too many
    ok !eval { $stack->pop }, "asserts when popping off one too many";
}

done_testing;
