use strict;
use warnings;

use Test::CanThread qw/AUTHOR_TESTING/;

use threads;
use Test::More;
use Test::Stream;
use Test::Stream::Tester;

events_are(
    intercept {
        my $thr = threads->create(sub {
            subtest foo => sub {
                ok(1, "result in subtest");
            };
        });
        $thr->join;
        done_testing;
    },
    check {
        event note => {};
        event subtest => {
            pass => 1,
            events => check {
                event ok => { pass => 1 };
            },
        };
    },
    "thread before subtest works as expected"
);

events_are(
    intercept {
        subtest foo => sub {
            my $thr = threads->create(sub {
                ok(1, "result in subtest");
            });
            $thr->join;
        };
        done_testing;
    },
    check {
        event note => {};
        event subtest => {
            pass => 1,
            events => check {
                event ok => { pass => 1 };
            },
        };
    },
    "thread inside subtest works as expected"
);

my ($events, @warnings, $passing);
{
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    intercept {
        subtest foo => sub {
            ok(1, "first result in subtest");
            my $thr = threads->create(sub {
                sleep 1;
                ok(1, "last result in subtest");
            });
            $thr->detach; # Note: This is a dumb thing to do.
        };
        sleep 2;
        done_testing;
        $passing = Test::Stream->shared->is_passing;
    };
}

ok(!$passing, "The test will not pass after the subtest desync");
is(@warnings, 1, "1 warnings");
like(
    $warnings[0],
    qr/Attempted to send an event to subtest that has already completed/,
    "got warning about subtest in parent completing"
);

done_testing;
