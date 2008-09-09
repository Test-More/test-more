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

{
    my $result = $new_ok->( raw_passed => 1 );
    isa_ok $result, "Test::Builder2::Result::Pass";

    ok $result->passed;
    ok $result->raw_passed;
}

{
    my $result = $new_ok->( raw_passed => 0 );
    isa_ok $result, "Test::Builder2::Result::Fail";

    ok !$result->passed;
    ok !$result->raw_passed;
}

{
    my $result = $new_ok->(
        directive => 'skip',
    );
    isa_ok $result, "Test::Builder2::Result::Skip";

    ok $result->passed;
    ok $result->raw_passed;
    is $result->directive,      'skip';
}

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

