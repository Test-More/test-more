use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Trap; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use ok 'Test::Trap';

trap { exit 100 };
is($trap->exit, 100, "got exit");

done_testing;
