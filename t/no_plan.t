require Test;
Test::plan(tests => 12);

require Test::Simple;

push @INC, 't', '.';
require Catch;
my($out, $err) = Catch::caught();

eval {
    Test::Simple->import;
};

Test::ok($$out, '');
Test::ok($$err, '');
Test::ok($@, '/You have to tell Test::Simple how many tests you plan to run/');

eval {
    Test::Simple->import(tests => undef);
};

Test::ok($$out, '');
Test::ok($$err, '');
Test::ok($@,
         '/Got an undefined number of tests/');

eval {
    Test::Simple->import(tests => 0);
};

Test::ok($$out, '');
Test::ok($$err, '');
Test::ok($@, '/You told Test::Simple you plan to run 0 tests!/');

eval {
    Test::Simple::ok(1);
};
Test::ok( $@, '/You tried to use ok\(\) without a plan!/');


END {
    Test::ok($$out, '');
    Test::ok($$err, "# No tests run!\n");

    # Prevent Test::Simple from exiting with non zero.
    exit 0;
}
