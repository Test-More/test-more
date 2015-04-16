use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Fennec; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use ok 'Fennec';

describe foo => sub {
    tests bar => sub {
        ok(1, "one");
        ok(2, "two");
    };
};

done_testing;
