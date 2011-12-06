#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Events;
use TB2::EventCoordinator;

my $CLASS = 'TB2::OnlyOnePlan';
use_ok $CLASS;


note "Two plans from two different coordinators to one handler is ok"; {
    my $onlyone = $CLASS->new;

    # Deliberately put the same handler into two coordinators
    my $ec1 = TB2::EventCoordinator->new(
        formatters      => [],
        early_handlers  => [$onlyone]
    );
    my $ec2 = TB2::EventCoordinator->new(
        formatters      => [],
        early_handlers  => [$onlyone]
    );

    # start testing in both coordinators
    my $start = TB2::Event::TestStart->new;
    $_->post_event($start) for $ec1, $ec2;

    ok eval {
        $ec1->post_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 3,
                file             => "bar.t",
                line             => 42,
            )
        );
        1;
    }, "one plan is ok" or diag $@;

    ok eval {
        $ec2->post_event(
            TB2::Event::SetPlan->new(
                asserts_expected => 4,
                file             => "foo.t",
                line             => 23,
            )
        );
        1;
    }, "a plan in another coordinator is ok" or diag $@;
}

done_testing;
