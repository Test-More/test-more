use strict;

require Test;
Test::plan(tests => 2);

require Test::Simple;

push @INC, 't', '.';
require Catch;
my($out, $err) = Catch::caught();

Test::Simple->import(tests => 5);

ok( 1, 'passing' );
ok( 2, 'passing still' );
ok( 3, 'still passing' );
ok( 0, 'oh no!' );
ok( 0, 'damnit' );


END {
    Test::ok($$out, <<OUT);
1..5
ok 1 - passing
ok 2 - passing still
ok 3 - still passing
not ok 4 - oh no!
not ok 5 - damnit
OUT

    Test::ok($$err, <<ERR);
# Looks like you failed 2 tests of 5.
ERR

    # Prevent Test::Simple from exiting with non zero
    exit 0;
}
