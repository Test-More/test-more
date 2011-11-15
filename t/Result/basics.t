#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

{
    package TB2::Formatter::Noop;

    use Test::Builder2::Mouse;

    extends 'Test::Builder2::Formatter';

    sub end { }
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

    note "Pass"; {
        my $result = $new_ok->([ pass => 1 ]);

        ok $result->is_pass;
        ok !$result->is_fail;
        ok !$result->is_todo;
        ok !$result->is_skip;
        ok $result;
    }

    note "Fail"; {
        my $result = $new_ok->([ pass => 0 ]);

        is $result->type, 'fail';
        ok !$result;
    }


    note "Skip"; {
        my $result = $new_ok->([ pass => 1, directives => [qw(skip)] ]);

        is $result->type, 'skip_pass';
        is $result->reason, undef;
        ok $result->is_skip;
        ok $result;
    }


    note "TODO"; {
        my $result = $new_ok->([ pass => 1, directives => [qw(todo)] ]);

        is $result->type, 'todo_pass';
        ok $result->is_todo;
        ok $result;
    }

    note "skip todo"; {
        my $result = $new_ok->([ pass => 0, directives => [qw(todo skip)] ]);

        ok $result, 'Chained skip';
        is $result->type, 'todo_skip';
        ok $result->is_todo;
        ok $result->is_skip;
    }

    note "TODO with no message"; {
        my $result = $new_ok->([ pass => 0, directives => [qw(todo)] ]);

        ok $result->is_todo(), 'Todo with no message';
        is $result->reason, undef;
        ok $result;
    }

    note "as_hash"; {
        my $result = $new_ok->([
            pass            => 1,
            name            => 'something something something test result',
            test_number     => 23,
            file            => 'foo.t',
            line            => 1,
            event_type      => 'result',
        ]);

        is_deeply $result->as_hash, {
            type            => 'pass',
            name            => 'something something something test result',
            test_number     => 23,
            file            => 'foo.t',
            line            => 1,
            event_id        => $result->event_id,
            event_type      => 'result',
            diag            => [],
        }, 'as_hash';
    }
}

done_testing;
