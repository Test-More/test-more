use Test::More 'no_plan';

use strict;

test_these {
    print "Foo";
    skip "Because";
}
