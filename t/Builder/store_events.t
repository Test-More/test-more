#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib';

use Test::More store_events => 1;

my $tb = Test::More->builder;
ok $tb->store_events, "event storage is on";
is_deeply [$tb->summary], [1];

done_testing;
