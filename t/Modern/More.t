use strict;
use warnings;
use Test::More tests => 2, qw/modern/;

ok(1, "Result in parent" );

if (my $pid = fork()) {
    waitpid($pid, 0);
    cull();
}
else {
    ok(1, "Result in child");
    exit 0;
}

