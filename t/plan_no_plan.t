use Test::More;

BEGIN {
    require Test::Harness;
}

if( $Test::Harness::VERSION < 1.20 ) {
    plan skip_all => 'Need Test::Harness 1.20 or up';
}
else {
    plan 'no_plan';
}

pass('Just testing');
ok(1, 'Testing again');
