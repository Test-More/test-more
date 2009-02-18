#!/usr/bin/perl -w

use Test::Builder;

my $tb = Test::Builder->new;
$tb->level(0);

$tb->plan( add => 2 );
$tb->ok(1);
$tb->ok(1);

$tb->plan( add => 1 );
$tb->ok(1);

