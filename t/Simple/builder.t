#!/usr/bin/perl -w

use strict;
use warnings;

use Test::Simple tests => 3;

ok( defined Test::Simple->Builder );
ok( Test::Simple->Builder->isa("Test::Builder2") );

my $orig_builder = Test::Simple->Builder;
ok $orig_builder eq Test::Builder2->singleton;
