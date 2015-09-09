use Test::Stream(
    '-V1',          # Test loading a bundle
    ':ProjectBundle',    # Test project specific bundle
    'LoadPlugin',        # Test loading a plugin
    'IPC' => ['-cull'],  # Test plugin args

    # Blacklist
    'Spec',
    '!Spec', # Should override the listings above and below
    'Spec',

    # Make sure blacklist items are not even loaded
    'SomeFakePluginThatWillFail',
    '!SomeFakePluginThatWillFail',

    # Specify class, but then disallow it
    Class => ['Test::Stream'],
    '!+Test::Stream::Plugin::Class',

    # Test fully qualified plugin path
    '+Test::Stream::Plugin::Grab',

    '+-Test::Stream::Bundle::Tester',

    Compare => '*',

    # Other stuff we need:
    'Exception',
);

imported_ok(
    'ok',                 # Check that we loaded default
    'project_bundled',    # Check that we loaded the project bundle
    'load_plugin',        # Check that we loaded LoadPlugin
    'cull',               # Check that we loaded IPC with args
    'grab',               # Check that we loaded Grab
    'intercept',          # Check that we loaded the Tester bundle
    'DNE',                # Check that we loaded all of compare
);

# Make sure Class was not loaded
not_imported_ok('CLASS');

like(
    dies { Test::Stream->load([__FILE__, __PACKAGE__, __LINE__], ':XXX') },
    qr/Could not load LOCAL PROJECT bundle 'Test::Stream::Bundle::XXX' \(Do you need to set TS_LB_PATH\?\)/,
    "Helpful error"
);

# Test that the last one wins
not_imported_ok(qw/xxx yyy zzz tests describe/);
load_plugin(
    Intercept => [ 'intercept' => { -as => 'xxx' }],
    Intercept => [ 'intercept' => { -as => 'yyy' }],
    Intercept => [ 'intercept' => { -as => 'zzz' }],
);
not_imported_ok(qw/xxx yyy/);
imported_ok('zzz');

like(
    dies { Test::Stream->import },
    qr/No plugins or bundles specified, did you forget to add '-V1'/,
    "Must specify something to load"
);

{
    package Foo;
    use Test::Stream 'Core';
    imported_ok('ok');
}

like(
    dies { load_plugin( Class => ['1Fake::Class'] ) },
    qr{Can't locate 1Fake/Class\.pm},
    "Reports why module failed internally"
);

like(
    dies { load_plugin( '+1Fake::Plugin' ) },
    qr{Could not load Test::Stream plugin '1Fake::Plugin'},
    "Reports why module failed in Test::Stream"
);

like(
    dies { load_plugin( '+1Fake::Plugin' ) },
    mismatch qr{Stream\.pm line \d+},
    "Did not report into Test::Stream itself"
);


done_testing;
