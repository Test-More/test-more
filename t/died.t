#!perl -w

use lib 't/lib';
use absINC;

# Can't use Test.pm, that's a 5.005 thing.
package My::Test;

# This has to be a require or else the END block below runs before
# Test::Builder's own and the ending diagnostics don't come out right.
require Test::Builder;
my $TB = Test::Builder->create;
$TB->plan(tests => 3);


package main;

require Test::Simple;

chdir 't';

require Test::Simple::Catch;
my($out, $err) = Test::Simple::Catch::caught();
local $ENV{HARNESS_ACTIVE} = 0;

Test::Simple->import(tests => 1);
exit 250;

END {
     $TB->is_eq($out->read, <<OUT);
TAP version 13
1..1
OUT

    $TB->is_eq($err->read, <<ERR);
# No tests run!
# Looks like your test exited with 250 before it could output anything.
ERR

    $TB->is_eq($?, 250, "exit code");

    exit grep { !$_ } $TB->summary;
}
