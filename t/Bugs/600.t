use Test::Stream qw/-V1 Intercept Compare */;
use Test::Builder;

my $TEST = Test::Builder->new();

sub fake {
    $TEST->use_numbers(0);
    $TEST->no_ending(1);
    $TEST->done_testing(1);    # a computed number of tests from its deferred magic
}

is(
    intercept { fake() },
    array {
        event Plan => { max => 1 };
    },
    "Plan is set to 1, not 0"
);

done_testing;
