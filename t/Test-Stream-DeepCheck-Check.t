use strict;
use warnings;

use Test::More;

use Test::Stream::DeepCheck::Check;
my $CLASS = 'Test::Stream::DeepCheck::Check';

use Test::Stream::Interceptor qw/dies no_warnings/;
use Test::Stream::DebugInfo;

my $dbg = Test::Stream::DebugInfo->new(frame => []);

ok no_warnings {
    like(
        dies { $CLASS->new(debug => $dbg) },
        qr/op is a required attribute/,
        "must have op"
    );

    like(
        dies { $CLASS->new(op => 'foo', debug => $dbg) },
        qr/'foo' is not a known operator for $CLASS/,
        "op must be valid"
    );

    ####
    # Custom check
    ####
    my $one = $CLASS->new(op => sub { 1 }, debug => $dbg, val => 'b');

    is($one->diag('a'),   "custom('a', 'b')",   "Diag for custom with string arg");
    is($one->diag(22),    "custom(22, 'b')",    "Diag for custom with number arg");
    is($one->diag(undef), "custom(undef, 'b')", "Diag for custom with undef arg");
    is($one->diag(),      "custom(..., 'b')", "Diag for custom no arg");

    isa_ok($one, $CLASS);
    is($one->_run->(), 1, "Always true");
    ok($one->verify(undef, undef), "Always true");

    $one = $CLASS->new(op => sub { $_[0] eq $_[1] }, val => 'a', debug => $dbg);
    my $ok = $one->verify('a');
    ok($ok, "verified");

    $ok = $one->verify('b');
    ok(!$ok, "not verified");

    ####
    # Numeric
    ####
    $one = $CLASS->new(op => '==', val => 42, debug => $dbg);

    is($one->diag(22),    "22 == 42",    "Diag for number with numeric arg");
    is($one->diag('foo'), "'foo' == 42", "Diag for number with string arg");
    is($one->diag(undef), "undef == 42", "Diag for number with undef arg");
    is($one->diag(),      '... == 42',  "Diag for number no arg");

    $ok = $one->verify(42);
    ok($ok, "verify 42 == 42");

    $ok = $one->verify(44);
    ok(!$ok, "not verified");

    $ok = $one->verify(undef);
    ok(!$ok, "not verified");

    $one = $CLASS->new(op => '==', val => undef, debug => $dbg);
    $ok = $one->verify(42);
    ok(!$ok, "not verified");

    ####
    # String
    ####
    $one = $CLASS->new(op => 'eq', val => 'foo', debug => $dbg);

    is($one->diag('foo'), "'foo' eq 'foo'", "Diag for string with string arg");

    $ok = $one->verify('foo');
    ok($ok, "verify 'foo' eq 'foo'");

    $ok = $one->verify('bar');
    ok(!$ok, "not verified");

    $ok = $one->verify(undef);
    ok(!$ok, "not verified");

    $one = $CLASS->new(op => 'eq', val => undef, debug => $dbg);
    $ok = $one->verify('foo');
    ok(!$ok, "not verified");

    $one = $CLASS->new(op => 'eq', val => 42, debug => $dbg);
    $ok = $one->verify(32);
    ok(!$ok, "not verified");

    ####
    # Regex
    ####
    my $regex_string = "" . qr/foo/;
    $one = $CLASS->new(op => '=~', val => qr/foo/, debug => $dbg);

    is($one->diag('foo'), "'foo' =~ $regex_string", "Diag for regex on string");
    is($one->diag( 444 ), "'444' =~ $regex_string", "Diag for regex on number (always stringify)");
    is($one->diag(undef), "undef =~ $regex_string", "Diag for regex on undef");
    is($one->diag(),      "... =~ $regex_string",   "Diag for regex on no arg");

    $ok = $one->verify('foo');
    ok($ok, "verify foo =~ qr/42/");

    $ok = $one->verify('bar');
    ok(!$ok, "not verified");

    $ok = $one->verify(undef);
    ok(!$ok, "not verified");

    $ok = $one->verify(1000);
    ok(!$ok, "not verified");

    $ok = $one->verify({});
    ok(!$ok, "not verified");

    like(
        dies { $CLASS->new(op => '=~', val => undef, debug => $dbg) },
        qr/val must be a regex when op is '=~', got: undef/,
        "Regex cannot be undef"
    );

    like(
        dies { $CLASS->new(op => '=~', val => 'foo', debug => $dbg) },
        qr/val must be a regex when op is '=~', got: 'foo'/,
        "val is not a regex"
    );

    like(
        dies { $CLASS->new(op => '=~', val => 42, debug => $dbg) },
        qr/val must be a regex when op is '=~', got: 42/,
        "val is still not a regex"
    );

    ####
    # Boolean
    ####
    $one = $CLASS->new(op => '!!', debug => $dbg);
    is($one->diag(1), "!! 1", "Diag for negated boolean");
    $ok = $one->verify(1);
    ok($ok, "verify !! 1");

    $ok = $one->verify(0);
    ok(!$ok, "not verified");

    $ok = $one->verify(undef);
    ok(!$ok, "not verified");

    $one = $CLASS->new(op => '!', debug => $dbg);
    is($one->diag(1), "! 1", "Diag for boolean");
    $ok = $one->verify('foo');
    ok(!$ok, "not verified");

    ####
    # Defined
    ####
    $one = $CLASS->new(op => 'defined', debug => $dbg);

    is($one->diag(undef), "defined undef", "Diag for undef");
    is($one->diag(1),     "defined 1",     "Diag for undef");
    is($one->diag(),      "defined ...",   "Diag for undef");

    $ok = $one->verify(1);
    ok($ok, "verify defined 1");

    $ok = $one->verify(undef);
    ok(!$ok, "not verified");

    $one = $CLASS->new(op => '!defined', debug => $dbg);
    $ok = $one->verify(undef);
    ok($ok, "verify !defined undef");

    $ok = $one->verify('foo');
    ok(!$ok, "not verified");

    ####
    # methods
    ####
    $one = $CLASS->new(op => 'can', val => 'debug', debug => $dbg);

    is($one->diag('foo'), "'foo'->can('debug')", "Diag for can string");
    is($one->diag(undef), "undef->can('debug')", "Diag for can undef");
    is($one->diag(),      "...->can('debug')",   "Diag for can empty ");

    $ok = $one->verify($CLASS);
    ok($ok, "verify $CLASS\->can('debug')");

    $one = $CLASS->new(op => 'can', val => 'somethingveryfake', debug => $dbg);
    $ok = $one->verify($CLASS);
    ok(!$ok, "Fail $CLASS\->can('somethingveryfake')");

    $one = $CLASS->new(op => '!can', val => 'somethingveryfake', debug => $dbg);
    $ok = $one->verify($CLASS);
    ok($ok, "verify !$CLASS\->can('somethingveryfake')");

    $one = $CLASS->new(op => '!can', val => 'debug', debug => $dbg);
    $ok = $one->verify($CLASS);
    ok(!$ok, "Fail !$CLASS\->can('debug')");

    is($one->diag('foo'), "!'foo'->can('debug')", "Diag for can string");
    is($one->diag(undef), "!undef->can('debug')", "Diag for can undef");
    is($one->diag(),      "!...->can('debug')",   "Diag for can empty ");

    ####
    # functions
    ####
    $one = $CLASS->new(op => 'blessed', val => $CLASS, debug => $dbg);

    is($one->diag('foo'), "blessed('foo') eq '$CLASS'", "Diag for blessed");

    $ok = $one->verify($one);
    ok($ok, "blessed(\$one) eq '$CLASS'");

    $one = $CLASS->new(op => 'blessed', val => 'Something::Fake', debug => $dbg);
    $ok = $one->verify($one);
    ok(!$ok, "Fail blessed(\$one) eq 'Something::Fake'");

    $one = $CLASS->new(op => '!blessed', val => $CLASS, debug => $dbg);
    $ok = $one->verify($one);
    ok(!$ok, "Fail !blessed(\$one) eq $CLASS");

    is($one->diag('foo'), "!blessed('foo') eq '$CLASS'", "Diag for !blessed");

    ####
    # Register
    ####
    Test::Stream::DeepCheck::Check::register_op(
        foo => (
            run => sub { 1 },
            diag => sub { 'go away' },
            neg => 1,
        ),
    );

    $one = $CLASS->new(op => 'foo', debug => $dbg);
    $ok = $one->verify(1);
    ok($ok, "custom op");
    is($one->diag, 'go away', "custom diag");

    $one = $CLASS->new(op => '!foo', debug => $dbg);
    $ok = $one->verify(1);
    ok(!$ok, "custom op negate");

}, "No unexpected warnings";

done_testing;
