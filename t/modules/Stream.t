use Test::Stream(
    '-Default',          # Test loading a bundle
    ':ProjectBundle',    # Test project specific bundle
    'LoadPlugin',        # Test loading a plugin
    'IPC' => ['-cull'],  # Test plugin args

    # Test fully qualified plugin path
    '+Test::Stream::Plugin::Grab',

    # Other stuff we need:
    'Exception',
);

imported(
    'ok',                 # Check that we loaded default
    'project_bundled',    # Check that we loaded the project bundle
    'load_plugin',        # Check that we loaded LoadPlugin
    'cull',               # Check that we loaded IPC with args
    'grab',               # Check that we loaded Grab
);

like(
    dies { Test::Stream->load([__FILE__, __PACKAGE__, __LINE__], ':XXX') },
    qr/Could not load LOCAL PROJECT bundle 'Test::Stream::Bundle::XXX' \(Do you need to set TS_LB_PATH\?\)/,
    "Helpful error"
);

# Test that the last one wins
not_imported(qw/xxx yyy zzz/);
load_plugin(
    Intercept => [ 'intercept' => { -as => 'xxx' }],
    Intercept => [ 'intercept' => { -as => 'yyy' }],
    Intercept => [ 'intercept' => { -as => 'zzz' }],
);
not_imported(qw/xxx yyy/);
imported('zzz');

done_testing;
