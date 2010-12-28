#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

# Turn off use_numbers
{
    $tb->use_numbers(0);
    $tb->plan( tests => 2 );
    $tb->ok(1);
    $tb->ok(0, "a name");
}


is($tb->read("out"), <<"END");
TAP version 13
1..2
ok
not ok - a name
END

done_testing;
