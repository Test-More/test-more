#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Simple tests => 4;

ok( defined Test::Simple->builder );
ok( Test::Simple->builder->isa("Test::Builder2") );

my $orig_builder = Test::Simple->builder;
my $new_builder  = Test::Builder2->new;
Test::Simple->builder($new_builder);
ok( Test::Simple->builder == $new_builder );

ok( $Test::Simple::Builder == $new_builder );
