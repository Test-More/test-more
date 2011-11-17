#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Simple ();

ok( defined Test::Simple->builder );
ok( Test::Simple->builder->isa("Test::Builder") );

my $orig_builder = Test::Simple->builder;
is $orig_builder, Test::Builder->new;

done_testing;
