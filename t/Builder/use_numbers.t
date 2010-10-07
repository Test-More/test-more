#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';

use Test::Builder;
use Test::Builder::NoOutput;

my $tb = Test::Builder::NoOutput->create;

# Turn off use_numbers
{
    $tb->use_numbers(0);
    $tb->plan( tests => 2 );
    $tb->ok(1);
    $tb->ok(0, "a name");
}


my $Test = Test::Builder->new;
$Test->plan( tests => 1 );
$Test->level(0);
$Test->is_eq($tb->read("out"), <<"END");
1..2
ok
not ok - a name
END
