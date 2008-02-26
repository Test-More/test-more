#!/usr/bin/perl -w

use Test::Builder;
use Test::Builder::Module;

my $TB = Test::Builder->create;
$TB->plan( tests => 1 );
$TB->level(0);

$TB->is_eq( Test::Builder::Module->builder->exported_to,
            undef,
            'using Test::Builder::Module does not set exported_to()'
);