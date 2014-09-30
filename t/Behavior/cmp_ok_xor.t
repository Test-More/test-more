use strict;
use warnings;

use Test::More 'modern';

my @warnings;
$SIG{__WARN__} = sub { push @warnings => @_ };
my $ok = cmp_ok( 1, 'xor', 0, 'use xor in cmp_ok' );
ok(!@warnings, "no warnings");
ok($ok, "returned true");

done_testing;
