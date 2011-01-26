#!/usr/bin/perl

# Test that TB1 works without a formatter

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder2::EventCoordinator;

# Pull the formatter
my $ec = Test::Builder2::EventCoordinator->singleton;
$ec->clear_formatters;

require Test::Builder;
my $tb = Test::Builder->new;

is $tb->current_test, 0;
ok eval { $tb->ok(1); };
is $tb->current_test, 1;
ok eval { $tb->ok(1, "second test") };
is $tb->current_test, 2;

done_testing;
