#!/usr/bin/perl -w

# Ensure that import handles the special 'no_plan' case.

use strict;
use warnings;

use Test::More;

{
    package My::Test;

    require Test::Builder::Module;
    our @ISA = qw(Test::Builder::Module);
}

note "special case for bare 'no_plan'"; {
    ok( !Test::Builder->new->has_plan );
    My::Test->import("no_plan");
    is( Test::Builder->new->has_plan, "no_plan", "no_plan set via import" );
}

done_testing;
