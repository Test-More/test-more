use strict;
use warnings;

use Test::More tests => 3;
BEGIN { eval { require Test::NoWarnings; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use Test::Stream::Tester;
use ok 'Test::NoWarnings';

ok(1, "pass");
done_testing;
