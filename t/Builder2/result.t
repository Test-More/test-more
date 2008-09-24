#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

my $CLASS = 'Test::Builder2::Result';
require_ok $CLASS;

my $new_ok = sub {
    my $result = $CLASS->new(@_);
    isa_ok $result, 'Test::Builder2::Result::Base';
    return $result;
};


# Pass
{
    my $result = $new_ok->( raw_passed => 1 );
    isa_ok $result, "Test::Builder2::Result::Pass";

    ok $result->passed;
    ok $result->raw_passed;
}


# Fail
{
    my $result = $new_ok->( raw_passed => 0 );
    isa_ok $result, "Test::Builder2::Result::Fail";

    ok !$result->passed;
    ok !$result->raw_passed;
}


# Skip
{
    my $result = $new_ok->(
        directive => 'skip',
    );
    isa_ok $result, "Test::Builder2::Result::Skip";

    ok $result->passed;
    ok $result->raw_passed;
    is $result->directive,      'skip';
}


# TODO
{
    my $result = $new_ok->(
        directive       => 'todo',
        raw_passed      => 0
    );
    isa_ok $result, "Test::Builder2::Result::Todo";

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

    isa_ok $result, "Test::Builder2::Result::Pass";

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

    isa_ok $result, "Test::Builder2::Result::Fail";

    ok !$result->passed;
    ok !$result->raw_passed;
    is $result->directive,      'omega';
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


# Register a new result type
{
    {
        package TB2::Result::NoTest;

        use Mouse;

        extends 'Test::Builder2::Result::TODO';

        __PACKAGE__->register_result(sub {
            my $args = shift;
            return $args->{directive} eq 'notest';
        });
    }

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
);
}
