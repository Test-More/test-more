use Test::More tests => 2;

ok( 1, 'One' );

require Test::SharedFork;

ok( 2, 'Two' );

