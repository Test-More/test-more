#!/usr/bin/perl -w

use strict;

{
    package TB2::Assert;

    require Test::Simple;
    use Test::Builder2::Mouse::Role;

    # Die after assert_end to give TB2 the chance to
    # print the result
    after assert_end => sub {
        my $self   = shift;
        my $result = shift;

        # Have to check that we're not in an assert because assert_end()
        # would have already popped the stack.
        die "Test said to die" if !$self->top_stack->in_assert and $result->name =~ /\b die \b/x;
    };

    TB2::Assert->meta->apply(Test::Simple->builder);
}


use Test::Simple tests => 3;
ok(1, "pass");

ok( !eval {
    ok(1, "die die die!");
    1;
}, "assert() dies on fail");

