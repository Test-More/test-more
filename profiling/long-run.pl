use strict;
use warnings;
use Test::More;# 'modern';

open( my $fh, '>', '/dev/null' );

my $tb = Test::Builder->new;

    $tb->output($fh);
    $tb->failure_output($fh);
    $tb->todo_output ($fh);

for (1 .. 1000) {
    print "Loop: $_\n";

    run();

    subtest foo => sub {
        run()
    }
}

sub run {
    ok($_, "pass") for 1 .. 10;

    is(1, 1, "is pass") for 1 .. 10;
    is("foo", "foo", "is pass 2") for 1 .. 10;

    is_deeply(
        {a => {a => {a => {a => {a => $_}}}}},
        {a => {a => {a => {a => {a => $_}}}}},
        'hash pass',
    ) for 1 .. 10;

    like( 'aaa', qr/a/, "Like pass" ) for 1 .. 10;

    TODO: {
        local $TODO = "Blah";
        ok(1, "todo pass");
    }

    SKIP: {
        skip 'foo' => 5;
        die "oops";
    }
}

done_testing;
