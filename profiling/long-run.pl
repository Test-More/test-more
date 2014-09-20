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
    ok($_, "pass") for 1 .. 100;

    is(1, 1, "is pass");

    is_deeply(
        { a => 1 },
        { a => 1 },
        'hash pass',
    );

    like( 'aaa', qr/a/, "Like pass" );

    TODO: {
        local $TODO = "Blah";
        ok(1, "todo pass");
    }

    subtest foo => sub {
        ok($_, "sub pass") for 1 .. 100;

        is(1, 1, "sub is pass");

        is_deeply(
            { a => 1 },
            { a => 1 },
            'sub hash pass',
        );

        like( 'aaa', qr/a/, "sub Like pass" );

        TODO: {
            local $TODO = "Blah";
            ok(1, "sub todo pass");
        }
    }
}

done_testing;
