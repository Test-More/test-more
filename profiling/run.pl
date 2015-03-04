use strict;
use warnings;
use Test::More;

run();

subtest foo => sub {
    run();
};

sub run {
    ok(1, "pass");

    is(1,     1,     "is pass");
    is("foo", "foo", "is pass 2");

    is_deeply(
        {a => {a => {a => {a => {a => 1}}}}},
        {a => {a => {a => {a => {a => 1}}}}},
        'hash pass',
    );

    like('aaa', qr/a/, "Like pass");

    TODO: {
        local $TODO = "Blah";
        ok(0, "todo pass");
    }

    SKIP: {
        skip 'foo' => 5;
        die "oops";
    }
}

done_testing;
