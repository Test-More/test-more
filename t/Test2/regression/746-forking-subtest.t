use strict;
use warnings;
use Test2::IPC;
use Test2::Tools::Tiny;
use Test2::API qw/context intercept test2_stack/;
use Test2::Util qw/CAN_FORK/;

BEGIN {
    skip_all "System cannot fork" unless CAN_FORK;
}

my $events = intercept {
    Test2::API::run_subtest("this subtest forks" => sub {
        if (fork) {
            wait;
            isnt($?, 0, "subprocess died");
        } else {
            die "# Expected warning from subtest";
        };
    });
};

my @subtests = grep {; $_->isa('Test2::Event::Subtest') } @$events;

if (is(@subtests, 1, "only one subtest run, effectively")) {
    my @subokay = grep {; $_->isa('Test2::Event::Ok') }
                  @{ $subtests[0]->subevents };
    is(@subokay, 1, "we got one test result inside the subtest");
    ok(! $subokay[0]->causes_fail, "...and it passed");
} else {
  # give up, we're already clearly broken
}

done_testing;
