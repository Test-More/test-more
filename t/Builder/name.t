#!/usr/bin/perl -w

use strict;
use warnings;

use lib 't/lib';
use Test::Builder::NoOutput;

BEGIN { require 't/test.pl' }

note "name test"; {
#line 16
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    is($tb->name, __FILE__, "Test name is correct");

    $tb->subtest( first_subtest => sub {
        $tb->plan('no_plan');
        is($tb->name, 'first_subtest', "Subtest name is correct");

        $tb->subtest( second_subtest => sub {
            is($tb->name, 'second_subtest', "Depth subtest name is correct");
        });

        is($tb->name, 'first_subtest', "Subtest name is correct back in parent");
    });

    is($tb->name, __FILE__, "Main test name is still correct");
}

done_testing;
