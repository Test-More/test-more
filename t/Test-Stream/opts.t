use Test::Stream qw/-warnings -strict -hook/;
use Test::Stream::Interceptor qw/warns dies lives/;

ok( 
    lives { no warnings; eval "\$x = 'foo'" || die $@ }, 
    "Strict is not enabled"
);

ok( !warns { my $x; $x =~ m/foo/ }, "Warnings are not enabled");

BEGIN {
    ok( !Test::Stream::Sync->hooks, "hook not added");
}

use Test::Stream;
like(
    dies {no warnings; eval "\$x = 'foo'" || die $@ },
    qr/"\$x" requires explicit package name/,
    "strict appears to be enabled"
);

mostly_like(
    warns { my $x; $x =~ m/foo/ },
    [ qr/uninitialized value.*in pattern match/ ],
    "warnings appear to be enabled"
);

ok( Test::Stream::Sync->hooks, "hook added");

done_testing;
