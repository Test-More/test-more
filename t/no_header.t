use Test::Builder;

BEGIN {
    Test::Builder->new->no_header(1);
}

use Test::More tests => 1;

print "1..1\n";
pass;
