#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use Test::Simple ();

ok( defined Test::Simple->Builder );
ok( Test::Simple->Builder->isa("Test::Builder2") );

my $orig_builder = Test::Simple->Builder;
is $orig_builder, Test::Builder2->singleton;

done_testing;
