#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

{
    package TB2::Formatter::Noop;

    use Mouse;

    extends 'Test::Builder2::Formatter';

    sub end { }
    sub result {} 
    sub begin {}
}

my $CLASS = 'Test::Builder2::Result';
require_ok $CLASS;

note("Running tests using $CLASS");
tests(sub { new_ok($CLASS, @_) });

sub tests {
    my $new_ok = shift;

    # Pass
    {
        my $result = $new_ok->([ type => "pass" ]);

        is $result->type, 'pass';
        ok $result;
    }


    # Fail
    {
        my $result = $new_ok->([ type => "fail" ]);

        is $result->type, 'fail';
        ok !$result;
    }


    # Skip
    {
        my $result = $new_ok->([ type => 'skip_pass' ]);

        is $result->type, 'skip_pass';
        is $result->reason, undef;
        ok $result->is_skip;
        ok $result;
    }


    # TODO
    {
        my $result = $new_ok->([ type => 'todo_pass' ]);

        is $result->type, 'todo_pass';
        ok $result->is_todo;
        ok $result;
    }


    # TODO after a pass
    {
        my $result = $new_ok->([ type => 'pass' ])
          ->todo('Must do');

        ok $result->is_todo;
        is $result->type, 'todo_pass';
        is $result->reason, 'Must do';
        ok $result;
    }

    # TODO after a fail
    {
        my $result = $new_ok->([ type => 'fail' ])
          ->todo('Must do');

        ok $result->is_todo;
        is $result->type, 'todo_fail';
        is $result->reason, 'Must do';
        ok $result;
    }

    # skip todo
    {
        my $result = $new_ok->([ type    => 'skip_pass' ])
          ->todo('Implement');

        ok $result, 'Chained skip';
        is $result->type, 'todo_skip';
        ok $result->is_todo;
        ok $result->is_skip;
    }

    # TODO with no message
    {
        my $result = $new_ok->([ type => 'fail' ])
          ->todo();

        ok $result->is_todo(), 'Todo with no message';
        is $result->reason, undef;
        ok $result;
    }

    # Type validation
    {
        ok !eval {
            Test::Builder2::Result->new([ type => 'spam' ]);
        }, 'Check type validation';
    }

    # as_hash
    {
        my $result = $new_ok->([
            type            => 'pass',
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
