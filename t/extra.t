require Test;
Test::plan(tests => 2);

require Test::Simple;

push @INC, 't', '.';
require Catch;
my($out, $err) = Catch::caught();

Test::Simple->import(tests => 3);

ok(1, 'Foo');
ok(0, 'Bar');
ok(1, 'Yar');
ok(1, 'Car');
ok(0, 'Sar');

END {
    Test::ok($$out, <<OUT);
1..3
ok 1 - Foo
not ok 2 - Bar
ok 3 - Yar
ok 4 - Car
not ok 5 - Sar
OUT

    Test::ok($$err, <<ERR);
# Looks like you planned 3 tests but ran 2 extra.
ERR

    exit 0;
}
