use strict;
use warnings;

{
    package Worker;

    sub do_work {
        local $Test::Builder::Level = $Test::Builder::Level + 2;
        shift->();
    }
}

use Test::More;
use SQL::Abstract::Test;
use Test::Tester2;

my $results = intercept {
    local $TODO = "Not today";

    Worker::do_work(
        sub {

            SQL::Abstract::Test::is_same_sql_bind(
                'buh', [],
                'bah', [1],
            );

        }
    );
};

results_are(
    $results,
    ok   => { in_todo => 1 },
    diag => { in_todo => 1 },
    note => { in_todo => 1 },
    note => { in_todo => 1 },
    'end'
);

done_testing;
