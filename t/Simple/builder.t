#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Simple tests => 5;

ok( defined Test::Simple->builder );
ok( Test::Simple->builder->isa("Test::Builder2") );

my $orig_builder = Test::Simple->builder;
ok $orig_builder eq Test::Builder2->singleton;

my $new_builder  = Test::Builder2->create;
Test::Simple->builder($new_builder);
ok( Test::Simple->builder eq $new_builder );

ok( $Test::Simple::Builder eq $new_builder );
