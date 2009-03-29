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

my $output = TB2::Output::Noop->new();

my $CLASS = 'Test::Builder2::Result';
my $WRAPPERCLASS = 'Test::Builder2::ResultWrapper';
require_ok $CLASS;
require_ok $WRAPPERCLASS;

my $new_ok = sub {
    my $inner = $CLASS->new(@_);
    my $result = $WRAPPERCLASS->new(result => $inner, output => $output);
    isa_ok $result, 'Test::Builder2::Result';
    return $result;
};

# Pass
{
    my $result = $new_ok->( raw_passed => 1 );
    isa_ok $result, "Test::Builder2::Result";

    ok $result->passed;
    ok $result->raw_passed;
}


# Fail
{
    my $result = $new_ok->( raw_passed => 0 );
    isa_ok $result, "Test::Builder2::Result";

    ok !$result->passed;
    ok !$result->raw_passed;
}


# Skip
{
    my $result = $new_ok->(
        raw_passed      => 1,
        skip => '1',
    );
    isa_ok $result, "Test::Builder2::Result";

    ok $result->passed;
    ok $result->raw_passed;
    is $result->directive,      'skip';
}


# TODO
{
    my $result = $new_ok->(
        raw_passed      => 0,
        todo            => 1,
    );
    isa_ok $result, "Test::Builder2::Result";

    ok $result->passed;
    ok !$result->raw_passed;
    is $result->directive,      'todo';
}


# Unknown directive, pass
{
    my $result = $new_ok->(
        directive       => 'omega',
        raw_passed      => 1
    );

    isa_ok $result, "Test::Builder2::Result";

    ok $result->passed;
    ok $result->raw_passed;
    is $result->directive,      'omega';
}


# Unknown directive, fail
{
    my $result = $new_ok->(
        directive       => 'omega',
        raw_passed      => 0
    );

    isa_ok $result, "Test::Builder2::Result";

    ok !$result->passed;
    ok !$result->raw_passed;
    is $result->directive,      'omega';
}

# truthiness (FALSE)
{
    my $result = $new_ok->(
        raw_passed => 0
    );
    isa_ok $result, "Test::Builder2::Result";
    ok !$result, "truth check";
}

# truthiness (TRUE)
{
    my $result = $new_ok->(
        raw_passed => 1
    );
    isa_ok $result, "Test::Builder2::Result";
    ok $result, "truth check";
}

# setting todo
# FIXME: try setting a todo with an empty value
{
    my $result = $new_ok->(
        raw_passed => 1
    );
    $result->todo('implement me');
    ok $result->passed, "set todo";
    ok $result->todo, "set todo";
}


# as_hash
{
    my $result = $new_ok->(
        raw_passed      => 1,
        description     => 'something something something test result',
        test_number     => 23,
        location        => 'foo.t',
        id              => 0,
        directive       => '',
    );

    is_deeply $result->as_hash, {
        raw_passed      => 1,
        description     => 'something something something test result',
        test_number     => 23,
        passed          => 1,
        location        => 'foo.t',
        id              => 0,
        directive       => '',
    }, 'as_hash';
}


