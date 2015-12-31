use strict;
use warnings;

BEGIN { require "t/tools.pl" };
use Test2::Hub::State;
use Test2::Util::Trace;
use Test2::Event::Ok;
use Test2::Event::Diag;

use Test2::API qw/context/;

my $trace;
sub before_each {
    # Make sure there is a fresh trace object for each group
    $trace = Test2::Util::Trace->new(
        frame => ['main_foo', 'foo.t', 42, 'main_foo::flubnarb'],
    );
}

tests Passing => sub {
    my $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 1,
        name  => 'the_test',
    );
    ok($ok->increments_count, "Bumps the count");
    ok(!$ok->causes_fail, "Passing 'OK' event does not cause failure");
    is($ok->pass, 1, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 1, "effective pass");
    is($ok->diag, undef, "no diag");

    my $hub = Test2::Hub::State->new;
};

tests Failing => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    my $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 0,
        name  => 'the_test',
    );
    ok($ok->increments_count, "Bumps the count");
    ok($ok->causes_fail, "A failing test causes failures");
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 0, "effective pass");

    is(
        $ok->default_diag,
        "Failed test 'the_test'\nat foo.t line 42.",
        "default diag"
    );
};

tests fail_with_diag => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    my $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 0,
        name  => 'the_test',
        diag  => ['xxx'],
    );
    ok($ok->increments_count, "Bumps the count");
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 0, "effective pass");

    is_deeply(
        $ok->diag,
        [ "xxx" ],
        "Got diag"
    );
};

tests "Failing TODO" => sub {
    local $ENV{HARNESS_ACTIVE} = 1;
    local $ENV{HARNESS_IS_VERBOSE} = 1;
    my $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 0,
        name  => 'the_test',
        todo  => 'A Todo',
    );
    ok($ok->increments_count, "Bumps the count");
    is($ok->pass, 0, "got pass");
    is($ok->name, 'the_test', "got name");
    is($ok->effective_pass, 1, "effective pass is true from todo");

    $ok->set_diag([ $ok->default_diag ]);
    is_deeply(
        $ok->diag,
        [ "Failed (TODO) test 'the_test'\nat foo.t line 42." ],
        "Got diag"
    );

    $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 0,
        name  => 'the_test2',
        todo  => '',
    );
    ok($ok->effective_pass, "empty string todo is still a todo");
};

tests init => sub {
    like(
        exception { Test2::Event::Ok->new(trace => $trace, pass => 1, name => "foo#foo") },
        qr/'foo#foo' is not a valid name, names must not contain '#' or newlines/,
        "Some characters do not belong in a name"
    );

    like(
        exception { Test2::Event::Ok->new(trace => $trace, pass => 1, name => "foo\nfoo") },
        qr/'foo\nfoo' is not a valid name, names must not contain '#' or newlines/,
        "Some characters do not belong in a name"
    );

    my $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 1,
    );
    is($ok->effective_pass, 1, "set effective pass");

    $ok = Test2::Event::Ok->new(
        trace => $trace,
        pass  => 1,
        name => 'foo#foo',
        allow_bad_name => 1,
    );
    ok($ok, "allowed the bad name");
    ok($ok->increments_count, "Bumps the count");
};

tests default_diag => sub {
    my $ok = Test2::Event::Ok->new(trace => $trace, pass => 1);
    is_deeply([$ok->default_diag], [], "no diag for a pass");

    $ok = Test2::Event::Ok->new(trace => $trace, pass => 0);
    like($ok->default_diag, qr/Failed test at foo\.t line 42/, "got diag w/o name");

    $ok = Test2::Event::Ok->new(trace => $trace, pass => 0, name => 'foo');
    like($ok->default_diag, qr/Failed test 'foo'\nat foo\.t line 42/, "got diag w/name");
};

done_testing;
