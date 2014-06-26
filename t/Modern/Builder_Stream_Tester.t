use strict;
use warnings;

use Test::More 'modern';
use Test::Builder::Stream::Tester;

can_ok( __PACKAGE__, 'intercept' );

my $results = intercept {
    ok(1, "Woo!");
    ok(0, "Boo!");
};

isa_ok($results->[0], 'Test::Builder::Result::Ok');
is($results->[0]->bool, 1, "Got one success");
is($results->[0]->name, "Woo!", "Got test name");

isa_ok($results->[1], 'Test::Builder::Result::Ok');
is($results->[1]->bool, 0, "Got one fail");
is($results->[1]->name, "Boo!", "Got test name");

$results = intercept {
    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$results, 2, "Only got 2");
isa_ok($results->[0], 'Test::Builder::Result::Ok');
isa_ok($results->[1], 'Test::Builder::Result::Bail');

$results = intercept {
    plan skip_all => 'All tests are skipped';

    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$results, 1, "Only got 1");
isa_ok($results->[0], 'Test::Builder::Result::Plan');

done_testing;
