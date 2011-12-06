#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl' }

use TB2::Event::SetPlan;

note "Basic event"; {
    my $event = TB2::Event::SetPlan->new;

    is $event->event_type, "set_plan";

    my $data = $event->as_hash;
    is $data->{asserts_expected},       0;
    ok !$data->{no_plan};
    ok !$data->{skip};
    is $data->{skip_reason},            '';
    is keys %{$data->{plan}},           0;
    is $data->{event_type},             "set_plan";
}

note "Basic event with a plan"; {
    my $event = TB2::Event::SetPlan->new(
        asserts_expected        => 23,
        plan                    => { this => "that" }
    );

    is $event->event_type, "set_plan";

    my $data = $event->as_hash;

    is_deeply $data, {
        object_id                => $event->object_id,
        event_type              => 'set_plan',
        plan                    => { this => "that" },
        asserts_expected        => 23,
        no_plan                 => 0,
        skip                    => 0,
        skip_reason             => "",
    };

    ok !$data->{no_plan},                               "no_plan";
}


note "Skip"; {
    my $event = TB2::Event::SetPlan->new(
        skip                    => 1,
        skip_reason             => "i said so",
    );

    is $event->event_type, "set_plan";

    my $data = $event->as_hash;
    is $data->{asserts_expected},       0;
    ok !$data->{no_plan};
    ok $data->{skip},                                   "skip";
    is $data->{skip_reason},            "i said so",    "skip_reason";
    is $data->{event_type},             "set_plan";
}


done_testing;
