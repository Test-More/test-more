use strict;
use warnings;
use Test::More;

use Test::Builder::Stream::Tester;

can_ok( __PACKAGE__, 'intercept' );

my $results = intercept {
    ok(1, "Woo!");
    ok(0, "Boo!");
};

is(@$results, 2, "got both results");

is($results->[0]->bool, 1, "Got one success");
is($results->[0]->name, "Woo!", "Got test name");

is($results->[1]->bool, 0, "Got one fail");
is($results->[1]->name, "Boo!", "Got test name");

done_testing;
