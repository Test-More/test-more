use strict;
use warnings;

use Test::More;
use Test::Stream::Context qw/context/;
use Test::Stream::Interceptor qw{
    dies warning warns lives no_warnings
};

can_ok(
    __PACKAGE__,
    qw{dies warning warns lives no_warnings}
);

sub tool { context() };

my $exception = dies { die "xxx" };
like($exception, qr/^xxx at/, "Captured exception");
$exception = dies { 1 };
is($exception, undef, "no exception");

my $warning = warning { warn "xxx" };
like($warning, qr/^xxx at/, "Captured warning");

my $warnings = warns { 1 };
is($warnings, undef, "no warnings");
$warnings = warns { warn "xxx"; warn "yyy" };
is(@$warnings, 2, "2 warnings");
like($warnings->[0], qr/^xxx at/, "first warning");
like($warnings->[1], qr/^yyy at/, "second warning");

my $no_warn = no_warnings { ok(lives { 0 }, "lived") };
ok($no_warn, "no warning on live");

$warning = warning { ok(!lives { die 'xxx' }, "lived") };
like($warning, qr/^xxx at/, "warning with exception");

is_deeply(
    warns { warn "foo\n"; warn "bar\n" },
    [
        "foo\n",
        "bar\n",
    ],
    "Got expected warnings"
);

done_testing;
