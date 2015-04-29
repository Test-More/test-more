use strict;
use warnings;

use Test::CanFork qw/AUTHOR_TESTING/;

use Test::More tests => 5;
use Test::Stream qw/cull enable_concurrency/;
use Test::Stream::Tester;

events_are(
    intercept {
        enable_concurrency();
        my $pid = fork();
        if ($pid) {
            waitpid($pid, 0);
            cull;
            return;
        }

        subtest foo => sub {
            ok(1, "result in subtest");
        };

        exit 0;
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
    "Fork before subtest works as expected"
);

events_are(
    intercept {
        enable_concurrency();
        subtest foo => sub {
            my $pid = fork();
            if ($pid) {
                waitpid($pid, 0);
                return;
            }

            ok(1, "result in subtest");
            exit 0;
        };
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
    "Fork inside subtest works as expected"
);

my ($events, @warnings, $passing);
{
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    intercept {
        enable_concurrency();
        subtest foo => sub {
            ok(1, "first result in subtest");
            my $pid = fork();
            return if $pid;

            sleep 1;
            ok(1, "last result in subtest");
            exit 0;
        };
        sleep 2;
        cull;
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
