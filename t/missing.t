require Test;
Test::plan(tests => 2);

require Test::Simple;

push @INC, 't', '.';
require Catch;
my($out, $err) = Catch::caught();

Test::Simple->import(tests => 5);

ok(1, 'Foo');
ok(0, 'Bar');

END {
    Test::ok($$out, <<OUT);
1..5
ok 1 - Foo
not ok 2 - Bar
OUT

    Test::ok($$err, <<ERR);
# Looks like you planned 5 tests but only ran 2.
ERR

    exit 0;
}
