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

    is $tb->history->subtest_depth, 0,      "subtest_depth outside the subtest";
    ok !$tb->history->subtest;

    $tb->subtest( first_subtest => sub {
        $tb->plan('no_plan');

        is($tb->name, 'first_subtest', "Subtest name is correct");

        is $tb->history->subtest_depth, 1,  "subtest_depth inside a subtest";

        my $outer_subtest = $tb->history->subtest;
        ok $outer_subtest;

        $tb->subtest( second_subtest => sub {
            is($tb->name, 'second_subtest', "Depth subtest name is correct");

            is $tb->history->subtest_depth, 2,      "subtest_depth in a nested subtest";

            my $inner_subtest = $tb->history->subtest;
            ok $inner_subtest;
            isnt $inner_subtest->object_id, $outer_subtest->object_id;
        });

        is $tb->history->subtest_depth, 1,                                  "subtest_depth restored";
        is $tb->history->subtest->object_id, $outer_subtest->object_id,     "subtest event restored";

        is($tb->name, 'first_subtest', "Subtest name is correct back in parent");
    });

    is($tb->name, __FILE__, "Main test name is still correct");
    is $tb->history->subtest_depth, 0,      "subtest_depth restored outside the subtest";
    ok !$tb->history->subtest;
}

done_testing;
