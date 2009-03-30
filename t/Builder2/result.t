#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

{
    package TB2::Output::Noop;

    use Mouse;

    extends 'Test::Builder2::Output';

    sub end { }
    sub result {} 
    sub begin {}
}

my $CLASS = 'Test::Builder2::Result';
my $WRAPPERCLASS = 'Test::Builder2::ResultWrapper';
require_ok $CLASS;
require_ok $WRAPPERCLASS;

note("Running tests using $CLASS");
tests(sub { new_ok($CLASS, @_) });

note("Running tests using $WRAPPERCLASS");
my $output = TB2::Output::Noop->new();
tests(sub {
    my $inner = $CLASS->new(@{$_[0]});
    my $result = $WRAPPERCLASS->new(result => $inner, output => $output);
    isa_ok $result, 'Test::Builder2::Result';
    return $result;
});


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
        my $result = $new_ok->([ type => 'skip' ]);

        is $result->type, 'skip';
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
        my $result = $new_ok->([ type    => 'skip' ])
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

    TODO: {
        local $TODO = "Should validate TB2::Result->type values";
        ok !eval {
            my $result = $new_ok->([ type => 'spam' ]);
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
