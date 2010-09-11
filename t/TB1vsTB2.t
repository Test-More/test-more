#!/usr/bin/perl

# Check that the TB1 and TB2 singletons work together in harmony

use strict;
use warnings;

use Test::More;

use Test::Builder;
use Test::Builder2;

my $tb1 = Test::Builder->new;
my $tb2 = Test::Builder2->singleton;

$tb1->plan( tests => 2 );
$tb2->ok( 1, "this is Test::Builder2" );
$tb1->ok( 1, "this is Test::Builder");
$tb2->stream_end;
