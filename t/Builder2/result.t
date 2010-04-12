#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

{
    package TB2::Formatter::Noop;

    use Test::Builder2::Mouse;

    extends 'Test::Builder2::Formatter';

    sub end { }
    sub result {} 
    sub begin {}
}

my $CLASS = 'Test::Builder2::Result';
require_ok $CLASS;

note("Running tests using $CLASS");
tests(sub {
    my $obj = $CLASS->new_result(@{$_[0]});
    isa_ok $obj, "Test::Builder2::Result::Base";
    return $obj;
});

sub tests {
    my $new_ok = shift;

    # Pass
    {
        my $result = $new_ok->([ pass => 1 ]);

        ok $result->is_pass;
        ok !$result->is_fail;
        ok !$result->is_todo;
        ok !$result->is_skip;
        ok $result;
    }

    # Fail
    {
        my $result = $new_ok->([ pass => 0 ]);

        is $result->type, 'fail';
        ok !$result;
    }


    # Skip
    {
        my $result = $new_ok->([ pass => 1, directives => [qw(skip)] ]);

        is $result->type, 'skip_pass';
        is $result->reason, undef;
        ok $result->is_skip;
        ok $result;
    }


    # TODO
    {
        my $result = $new_ok->([ pass => 1, directives => [qw(todo)] ]);

        is $result->type, 'todo_pass';
        ok $result->is_todo;
        ok $result;
    }

    # skip todo
    {
        my $result = $new_ok->([ pass => 0, directives => [qw(todo skip)] ]);

        ok $result, 'Chained skip';
        is $result->type, 'todo_skip';
        ok $result->is_todo;
        ok $result->is_skip;
    }

    # TODO with no message
    {
        my $result = $new_ok->([ pass => 0, directives => [qw(todo)] ]);

        ok $result->is_todo(), 'Todo with no message';
        is $result->reason, undef;
        ok $result;
    }

    # as_hash
    {
        my $result = $new_ok->([
            pass            => 1,
            description     => 'something something something test result',
            test_number     => 23,
            location        => 'foo.t',
            id              => 0,
        ]);

        is_deeply $result->as_hash, {
            type            => 'pass',
            description     => 'something something something test result',
            test_number     => 23,
            location        => 'foo.t',
            id              => 0,
        }, 'as_hash';
    }
}
