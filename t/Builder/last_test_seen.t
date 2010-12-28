#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';
BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

# there was a problem where Mouse attribute defaults were not being initialized
ok defined $tb->last_test_seen, 'last_test_seen is defined';

$tb->ok(1);
is $tb->last_test_seen, 1, 'last_test_seen tracks tests';

done_testing;
