#!/usr/bin/perl

# TB2 and Mouse have fought if loaded in the wrong order

use Test::Builder2;
use Mouse;

BEGIN { require 't/test.pl'; }

plan( tests => 1 );
pass('loads Mouse after Test::Builder2');
