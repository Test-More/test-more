use strict;
use warnings;
use Test::More;

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

isa_ok($results->[2], 'Test::Builder::Result::Diag');
is($results->[2]->message, "\n  Failed test 'Boo!'\n  at " . __FILE__ . " line 11.\n", "got error msg");

$results = intercept {
    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$results, 2, "Only got 2");
isa_ok($results->[0], 'Test::Builder::Result::Ok', "Got the first OK");
isa_ok($results->[1], 'Test::Builder::Result::Bail', "Got the Bailout");

$results = intercept {
    plan skip_all => 'All tests are skipped';

    ok(1, "Woo!");
    BAIL_OUT("Ooops");
    ok(0, "Should not see this");
};
is(@$results, 1, "Only got 1");
isa_ok($results->[0], 'Test::Builder::Result::Plan', "Got the skipall plan");

done_testing;
