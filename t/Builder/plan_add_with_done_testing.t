#!/usr/bin/perl -w

# plan( add => # ) could confuse done_testing() into not outputting a header
# immediately.

use lib 't/lib';

use Test::Builder;
use Test::Builder::NoOutput;

my $Test = Test::Builder->new;

{
    my $tb = Test::Builder::NoOutput->create;
    $tb->level(0);

    $tb->plan( add => 2 );
    $tb->ok(1);
    $tb->ok(1);

    $tb->plan( add => 1 );
    $tb->ok(1);

    $tb->done_testing(3);

    $Test->is_eq($tb->read, <<'END', "done_testing() should output a header immediately");
ok 1
ok 2
ok 3
1..3
END
}

$Test->done_testing(1);
