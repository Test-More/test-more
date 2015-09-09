use Test::Stream -V1, -Tester, Class => ['Test::Stream::Plugin::SRand'];

{
    local %ENV = %ENV;
    $ENV{HARNESS_IS_VERBOSE} = 1;
    $ENV{TS_RAND_SEED} = 1234;

    my $caller = [__PACKAGE__, __FILE__, __LINE__, 'xxx'];

    is(
        intercept { $CLASS->load_ts_plugin($caller, '5555') },
        array {
            event Note => { message => "Seeded srand with seed '5555' from import arg." };
        },
        "got the event"
    );
    is($CLASS->seed, 5555, "set seed");
    is($CLASS->from, 'import arg', "set from");

    my ($events, $warning);
    $warning = warning { $events = intercept { $CLASS->load_ts_plugin($caller) } };

    is(
        $events,
        array {
            event Note => { message => "Seeded srand with seed '1234' from environment variable." };
        },
        "got the event"
    );
    is($CLASS->seed, 1234, "set seed");
    is($CLASS->from, 'environment variable', "set from");

    like(
        $warning,
        qr/SRand loaded multiple times, re-seeding rand/,
        "Warned about resetting srand"
    );

    delete $ENV{TS_RAND_SEED};
    $warning = warning { $events = intercept { $CLASS->load_ts_plugin($caller) } };

    like(
        $events,
        array {
            event Note => { message => qr/Seeded srand with seed '\d{8}' from local date\./ };
        },
        "got the event"
    );
    ok($CLASS->seed && $CLASS->seed != 1234, "set seed");
    is($CLASS->from, 'local date', "set from");

    like(
        $warning,
        qr/SRand loaded multiple times, re-seeding rand/,
        "Warned about resetting srand"
    );

    my $hooks = Test::Stream::Sync->hooks;
    delete $ENV{HARNESS_IS_VERBOSE};
    warning { $events = intercept { $CLASS->load_ts_plugin($caller) } };
    warning { $events = intercept { $CLASS->load_ts_plugin($caller) } };
    is(Test::Stream::Sync->hooks, $hooks + 1, "added hook, but only once");

    warning { $CLASS->load_ts_plugin($caller, undef) };
    is($CLASS->seed, 0 , "set seed");
    is($CLASS->from, 'import arg', "set from");
}

done_testing();
