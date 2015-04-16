use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::NoWarnings; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
BEGIN { plan tests => 3 }
use Test::Stream::Tester;
use ok 'Test::NoWarnings';

ok(1, "pass");
done_testing;
