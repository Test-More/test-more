use strict;
use warnings;
use Test::Stream::DeferredTests;

my $START_LINE;
BEGIN {
    $START_LINE = __LINE__;
    def ok => (1, "truth");
    def is => (1, 1, "1 is 1");
    def is => ({}, {}, "hash is hash");

    def ok => (0, 'lies');
    def is => (0, 1, "1 is not 0");
    def is => ({}, [], "a hash is not an array");
}

use Test::Stream qw/-V1 -Tester Capture/;

is(
    intercept { do_def },
    array {
        event Ok => sub {
            call pass => 1;
            call name => 'truth';
            prop file => __FILE__;
            prop line => $START_LINE + 1;
            prop package => __PACKAGE__;
        };

        event Ok => sub {
            call pass => 1;
            call name => '1 is 1';
            prop file => __FILE__;
            prop line => $START_LINE + 2;
            prop package => __PACKAGE__;
        };

        event Ok => sub {
            call pass => 1;
            call name => 'hash is hash';
            prop file => __FILE__;
            prop line => $START_LINE + 3;
            prop package => __PACKAGE__;
        };

        event Ok => sub {
            call pass => 0;
            call name => 'lies';
            prop file => __FILE__;
            prop line => $START_LINE + 5;
            prop package => __PACKAGE__;
        };

        event Ok => sub {
            call pass => 0;
            call name => '1 is not 0';
            prop file => __FILE__;
            prop line => $START_LINE + 6;
            prop package => __PACKAGE__;
        };

        event Ok => sub {
            call pass => 0;
            call name => 'a hash is not an array';
            prop file => __FILE__;
            prop line => $START_LINE + 7;
            prop package => __PACKAGE__;
        };

        end;
    },
    "got expected events"
);

def ok => (1, "truth");
def is => (1, 1, "1 is 1");
def is => ({}, {}, "hash is hash");

# Actually run some that pass
do_def();

like(
    dies { do_def() },
    qr/No tests to run/,
    "Fails if there are no tests"
);

sub oops { die 'oops' }

def oops => (1);
like(
    dies { do_def() },
    qr/oops/,
    "Exceptions in the test are propogated"
);


{
    {
        package Foo;
        main::def ok => (1, "pass");
    }
    def ok => (1, "pass");
    local $? = 0;

    my $out = capture { Test::Stream::DeferredTests::_verify() };

    is($?, 255, "exit set to 255 due to unrun tests");
    like(
        $out->{STDOUT},
        qr/not ok - deferred tests were not run/,
        "Got failed STDOUT line"
    );

    like(
        $out->{STDERR},
        qr/# 'main' has deferred tests that were never run/,
        "We see that main failed"
    );

    like(
        $out->{STDERR},
        qr/# 'Foo' has deferred tests that were never run/,
        "We see that Foo failed"
    );
}

{
    local $? = 101;
    def ok => (1, "pass");
    my $out = capture { Test::Stream::DeferredTests::_verify() };
    is($?, 101, "did not change exit code");
    like(
        $out->{STDOUT},
        qr/not ok - deferred tests were not run/,
        "Got failed STDOUT line"
    );

    like(
        $out->{STDERR},
        qr/# 'main' has deferred tests that were never run/,
        "We see that main failed"
    );
}

done_testing;

__END__

        
