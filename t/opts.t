use Test::Stream qw/-Default Intercept/;
like(
    dies {no warnings; eval "\$x = 'foo'" || die $@ },
    qr/"\$x" requires explicit package name/,
    "strict appears to be enabled"
);

like(
    warns { my $x; $x =~ m/foo/ },
    [ qr/uninitialized value.*in pattern match/ ],
    "warnings appear to be enabled"
);

ok( Test::Stream::Sync->hooks, "hook added");

done_testing;
