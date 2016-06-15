use strict;
use warnings;

use Config;

BEGIN {
    unless ($Config{useithreads}) {
        print "1..0 # SKIP your perl does not support ithreads\n";
        exit 0;
    }
}

use threads;
use Test::More;

my $t = threads->create(
    sub {
        local $TODO = "Some good reason";

        fail "Crap";

        42;
    }
);

is(
    $t->join,
    42,
    "Thread exitted successfully"
);

done_testing;
