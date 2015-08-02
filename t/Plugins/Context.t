use Test::Stream -Default => qw/Context/;

BEGIN {
    can_ok(__PACKAGE__, qw/context/);
    ok(!__PACKAGE__->can('release'), "Did not import release");
}

use Test::Stream -Default => (
    Context => ['release'],
);

can_ok(__PACKAGE__, qw/context release/);

done_testing;
