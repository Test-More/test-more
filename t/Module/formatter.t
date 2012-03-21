#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder::Module;
use TB2::Formatter::Null;

my $Builder = Test::Builder->create;
note "Setup class for testing"; {
    package My::Test;
    our @ISA = qw(Test::Builder::Module);

    # Don't mess up the default builder, and test that
    # we respect a class' builder() method.
    sub builder { $Builder }
}


note "changing the formatter"; {
    package Foo;

    my $null1 = TB2::Formatter::Null->new;
    my $null2 = TB2::Formatter::Null->new;

    My::Test->import( formatter => $null1 );
    ::is( $Builder->formatter, $null1 );
    
    My::Test->import( tests => 10, formatter => $null2 );
    ::is( $Builder->formatter, $null2 );
    ::is( $Builder->has_plan, 10 );

    ::ok !Test::Builder->new->has_plan, "formatter respects a class' builder() method";
}

done_testing;
