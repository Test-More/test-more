#!/usr/bin/perl

# Test that TB1 works without a formatter

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::TestState;

# Pull the formatter
my $ec = TB2::TestState->default;
$ec->clear_formatters;

require Test::Builder;
my $tb = Test::Builder->new;

is $tb->current_test, 0;
ok eval { $tb->ok(1); };
is $tb->current_test, 1;
ok eval { $tb->ok(1, "second test") };
is $tb->current_test, 2;

done_testing;
