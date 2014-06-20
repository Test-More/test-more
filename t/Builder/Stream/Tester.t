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

{
    eval {
        intercept {
            BAIL_OUT( 'bail out' );
        };
    };

    like( $@, qr/bail out/, 'got bail out msg' );
}


{
    eval {
        intercept {
            plan skip_all => 'All tests are skipped';
        };
    };

    like( $@, qr/All tests are skipped/, 'got skip msg' );

}

done_testing;
