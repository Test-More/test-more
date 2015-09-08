use Test::Stream -V1 => qw/Context/;

BEGIN {
    can_ok(__PACKAGE__, qw/context/);
    ok(!__PACKAGE__->can('release'), "Did not import release");
}

use Test::Stream -V1 => (
    Context => ['release'],
);

can_ok(__PACKAGE__, qw/context release/);

done_testing;
