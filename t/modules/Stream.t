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

    # Options
    skip_without => 'Carp',
    class => 'Test::Stream',

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
    qr/No plugins or bundles specified \(Maybe try '-Classic'\?\)/,
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

like(
    dies { load_plugin('foo') },
    qr/'foo' is not a valid option for 'Test::Stream' \(Did you intend to use the 'Foo' plugin\?\)/,
    "Invalid option"
);

my $ran;
my $mock = mock 'Test::Stream' => (
    add => [ 'opt_foo' => sub {
        my ($class, %params) = @_;
        my $next = shift @{$params{list}};
        $ran = [@_, $next];
    }],
);

load_plugin('foo' => 'xyz');
is(
    $ran,
    [
        'Test::Stream',
        list => [],
        order => [],
        args => {},
        skip => {},
        'xyz'
    ],
    "got args"
);

my $list = [qw/foo bar baz/];
my $args = {};
my $order = [];
Test::Stream->opt_class(list => $list, args => $args, order => $order);
is($list, [qw/bar baz/], "shifted argument from list");
is($order, ['Test::Stream::Plugin::Class'], "Added Class to the load order");
is($args, {'Test::Stream::Plugin::Class' => ['foo']}, "added arg for class");
Test::Stream->opt_class(list => $list, args => $args, order => $order);
is($list, [qw/baz/], "shifted next argument from list");
is($order, ['Test::Stream::Plugin::Class'], "Added Class to the load order only once");
is($args, {'Test::Stream::Plugin::Class' => ['bar']}, "Changed arg for class");

$list = [qw/foo bar baz/];
$args = {};
$order = [];
Test::Stream->opt_skip_without(list => $list, args => $args, order => $order);
is($list, [qw/bar baz/], "shifted argument from list");
is($order, ['Test::Stream::Plugin::SkipWithout'], "Added SkipWithout to the load order");
is($args, {'Test::Stream::Plugin::SkipWithout' => ['foo']}, "added arg for skip_without");
Test::Stream->opt_skip_without(list => $list, args => $args, order => $order);
is($list, [qw/baz/], "shifted next argument from list");
is($order, ['Test::Stream::Plugin::SkipWithout'], "Added SkipWithout to the load order only once");
is($args, {'Test::Stream::Plugin::SkipWithout' => ['foo', 'bar']}, "added second arg for skip_without");

$list = [qw/foo bar baz/];
$args = {};
$order = [];
Test::Stream->opt_srand(list => $list, args => $args, order => $order);
is($list, [qw/bar baz/], "shifted argument from list");
is($order, ['Test::Stream::Plugin::SRand'], "Added SRand to the load order");
is($args, {'Test::Stream::Plugin::SRand' => ['foo']}, "added arg for SRand");
Test::Stream->opt_srand(list => $list, args => $args, order => $order);
is($list, [qw/baz/], "shifted next argument from list");
is($order, ['Test::Stream::Plugin::SRand'], "Added SRand to the load order only once");
is($args, {'Test::Stream::Plugin::SRand' => ['bar']}, "Changed arg for class");

done_testing;
