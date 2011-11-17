#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;

my $CLASS = 'TB2::OnlyOnePlan';
use_ok $CLASS;


note "Two different plans are not ok"; {
    my $onlyone = $CLASS->new;

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 3,
                file             => "bar.t",
                line             => 42,
            )
        );
        1;
    }, "one plan is ok";

    ok !eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 1,
                file             => "foo.t",
                line             => 99,
            )
        );
        1;
    }, "two different plans are not ok";
    like $@, qr{^Tried to set a plan at foo.t line 99, but a plan was already set at bar.t line 42\.$};
}


note "The same plan is ok"; {
    my $onlyone = $CLASS->new;

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 3,
                file             => "bar.t",
                line             => 42,
            )
        );
        1;
    }, "one plan is ok";

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 3,
                file             => "foo.t",
                line             => 99,
            )
        );
        1;
    }, "the same plans are ok";
}


note "Multiple no_plans are ok"; {
    my $onlyone = $CLASS->new;

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(no_plan => 1)
        );
        1;
    }, "one no_plan is ok";

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(no_plan => 1)
        );
        1;
    }, "two no_plans are ok";

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(asserts_expected => 3)
        );
        1;
    }, "a fixed number of tests after a no_plan is ok";

    ok !eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(asserts_expected => 23)
        );
        1;
    }, "another one is not";
}


note "Error message with no file/line"; {
    my $onlyone = $CLASS->new;

    ok eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(asserts_expected => 2)
        );
        1;
    }, "one plan is ok";

    ok !eval {
        $onlyone->accept_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 3,
            )
        );
        1;
    }, "two plans are not ok, even with the same number of tests";
    like $@, qr{^Tried to set a plan, but a plan was already set\.$};
}

done_testing;
