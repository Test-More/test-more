# NAME

Test::Stream - Experimental successor to Test::More and Test::Builder.

# \*\*\*READ THIS FIRST\*\*\*

**This is not a drop-in replacement for Test::More**.

Adoption of [Test::Stream](https://metacpan.org/pod/Test::Stream) instead of continuing to use [Test::More](https://metacpan.org/pod/Test::More) is a
choice. Liberty has been taken to make significant API changes. Replacing `use
Test::More;` with `use Test::Stream;` will not work for more than the most
trivial of test files.

See [Test::Stream::Manual::FromTestBuilder](https://metacpan.org/pod/Test::Stream::Manual::FromTestBuilder) if you are coming from
[Test::More](https://metacpan.org/pod/Test::More) or [Test::Simple](https://metacpan.org/pod/Test::Simple) and want a quick translation.

# \*\*\*COMBINING WITH OLD TOOLS\*\*\*

At the moment you cannot use [Test::Stream](https://metacpan.org/pod/Test::Stream) and [Test::Builder](https://metacpan.org/pod/Test::Builder) based tools
in the same test scripts unless you install the TRIAL [Test::More](https://metacpan.org/pod/Test::More) version.
Once the [Test::More](https://metacpan.org/pod/Test::More) trials go stable you will be able to combine tools from
both frameworks.

# MANUAL

The manual is still being written, but a couple pages are already available.

- Migrating from Test::More

    [Test::Stream::Manual::FromTestBuilder](https://metacpan.org/pod/Test::Stream::Manual::FromTestBuilder)

- How to write tools for Test::Stream

    [Test::Stream::Manual::Tooling](https://metacpan.org/pod/Test::Stream::Manual::Tooling)

- Overview of Test-Stream components

    [Test::Stream::Manual::Components](https://metacpan.org/pod/Test::Stream::Manual::Components)

# DESCRIPTION

This is the primary interface for loading [Test::Stream](https://metacpan.org/pod/Test::Stream) based tools. This
module is responsible for loading bundles and plugins for the tools you want.
By default you are required to specify at least 1 plugin or bundle to load. You
can subclass Test::Stream to have your own default plugins or bundles.

# SYNOPSIS

    use Test::Stream -Classic;

    ok(1, "This is a pass");
    ok(0, "This is a fail");

    done_testing;

## SUBCLASS

    package My::Loader;
    use strict;
    use warnings;

    use parent 'Test::Stream';

    sub default {
        return qw{
            -Bundle1
            Plugin1
            ...
        };
    }

    1;

# IMPORTANT NOTE

`use Test::Stream;` will fail. You **MUST** specify at least one bundle or
plugin. If you do not specify any then none would be imported and that is
obviously not what you want. If you are new to Test::Stream then you should
probably start with one of the pre-made bundles:

- '-Classic' - The 'Classic' bundle.

    This one is probably your best bet when just starting out. This plugin closely
    resembles the functionality of [Test::More](https://metacpan.org/pod/Test::More).

    See [Test::Stream::Bundle::Classic](https://metacpan.org/pod/Test::Stream::Bundle::Classic).

- '-V1' - The bundle used in Test::Streams tests.

    This one provides a lot more than the 'Classic' bundle, but is probably not
    suited to begginers. There are several notable differences from [Test::More](https://metacpan.org/pod/Test::More)
    that can trip you up if you do not pay attention.

    See [Test::Stream::Bundle::V1](https://metacpan.org/pod/Test::Stream::Bundle::V1).

## WHY NOT MAKE A DEFAULT BUNDLE OR SET OF PLUGINS?

Future Proofing. If we decide in the future that a specific plugin or tool is
harmful we would like to be able to remove it. Making a tool part of the
default set will effectively make it unremovable as doing so would break
compatability. Instead we have the bundle system, and a set of starter bundles,
if a bundle proves ot be harmful we can change the recommendation of the docs.

# PLUGINS, BUNDLES, AND OPTIONS

[Test::Stream](https://metacpan.org/pod/Test::Stream) tools should be created as plugins. This is not enforced,
nothing prevents you from writing [Test::Stream](https://metacpan.org/pod/Test::Stream) tools that are not plugins.
However writing your tool as a plugin will help your module to play well with
other tools. Writing a plugin also makes it easier for you to create private or
public bundles that reduce your boilerplate.

Bundles are very simple. At its core a bundle is simply a list of other
bundles, plugins, and arguments to those plugins. Much like hash declaration a
'last wins' approach is used; if you load 2 bundles that share a plugin with
different arguments, the last set of arguments wins.

Plugins and bundles can be distinguished easily:

    use Test::Stream(
        '-Bundle',                      # Bundle ('-')
        ':Project',                     # Project specific bundle (':')
        'MyPlugin',                     # Plugin name (no prefix)
        '+Fully::Qualified::Plugin',    # (Plugin in unusual path)
        'SomePlugin' => ['arg1', ...],  # (Plugin with args)
        '!UnwantedPlugin',              # Do not load this plugin
        'WantEverything' => '*',        # Load the plugin with all options
        'option' => ...,                # Option to the loader (Test::Stream)
    );

Explanation:

- '-Bundle',

    The `-` prefix indicates that the specified item is a bundle. Bundles live in
    the `Test::Stream::Bundle::` namespace. Each bundle is an independant module.
    You can specify any number of bundles, or none at all.

- ':Project'

    The ':' prefix indicates we are loading a project specific bundle, which means
    the module must be located in `t/lib/`, `lib/`, or the paths provided in the
    `TS_LB_PATH` environment variable. In the case of ':Project' it will look for
    `Test/Stream/Bundle/Project.pm` in `TS_LB_PATH`, `t/lib/`, then `lib/`.

    This is a good way to create bundles useful to your project, but not really
    worth putting on CPAN.

- 'MyPlugin'

    Arguments without a prefix are considered to be plugin names. Plugins are
    assumed to be in `Test::Stream::Plugin::`, which is prefixed automatically for
    you.

- '+Fully::Qualified::Plugin'

    If you write a plugin, but put it in a non-standard namespace, you can use the
    fully qualified plugin namespace prefixed by '+'. Apart from the namespace
    treatment there is no difference in how the plugin is loaded or used.

- 'SomePlugin' => \\@ARGS

    Most plugins provide a fairly sane set of defaults when loaded. However some
    provide extras you need to request. When loading a plugin directly these would
    be the import arguments. If your plugin is followed by an arrayref the ref
    contents will be used as load arguments.

    Bundles may also specify arguments for plugins. You can override the bundles
    arguments by specifying your own. In these cases last wins, arguments are never
    merged. If multiple bundles are loaded, and several specify arguments to the
    same plugin, the same rules apply.

        use Test::Stream(
            '-BundleFoo',         # Arguments to 'Foo' get squashed by the next bundle
            '-BundleAlsoWithFoo', # Arguments to 'Foo' get squashed by the next line
            'Foo' => [...],       # These args win
        );

- '!UnwantedPlugin'

    This will blacklist the plugin so that it will not be used. The blacklist will
    block the plugin regardless of where it is listed. The blacklist only effects
    the statement in which it appears; if you load Test::Stream twice, the
    blacklist will only apply to the load in which it appears. You cannot override
    the blacklist items.

- 'WantEverything' => '\*'

    This will load the plugin with all options. The '\*' gets turned into
    `['-all']` for you.

- 'option' => ...

    Uncapitalized options without a `+`, `-`, or `:` prefix are reserved for use
    by the loader. Loaders that subclass Test::Stream can add options of their own.

    To define an option in your subclass simply add a `sub opt_NAME()` method. The
    method will receive several arguments:

        sub opt_foo {
            my $class = shift;
            my %params = @_;

            my $list  = $params{list};  # List of remaining plugins/args
            my $args  = $params{args};  # Hashref of {plugin => \@args}
            my $order = $params{order}; # Plugins to load, in order
            my $skip  = $params{skip};  # Hashref of plugins to skip {plugin => $bool}

            # Pull our arguments off the list given at load time
            my $foos_arg = shift @$list;

            # Add the 'Foo' plugin to the list of plugins to load, unless it is
            # present in the $args hash in which case it is already in order.
            push @$order => 'Foo' unless $args{'Foo'};

            # Set the args for the plugin
            $args->{Foo} = [$foos_arg];

            $skip{Fox} = 1; # Make sure the Fox plugin never loads.
        }

## AVAILABLE OPTIONS

- class => $CLASS

    Shortcut for the [Test::Stream::Plugin::Class](https://metacpan.org/pod/Test::Stream::Plugin::Class) plugin.

- skip\_without => $MODULE
- skip\_without => 'v5.008'
- skip\_without => \[$MODULE => $VERSION\]

    Shortcut for the [Test::Stream::Plugin::SkipWithout](https://metacpan.org/pod/Test::Stream::Plugin::SkipWithout) plugin. Unlike normal
    specification of a plugin, this APPENDS arguments. This one can be called
    several time and the arguments will be appended.

    **Note:** specifying 'SkipWithout' the normal way after a call to 'skip\_without'
    will wipe out the argument that have accumulated so far.

- srand => $SEED

    Shortcut to set the random seed.

## SEE ALSO

For more about plugins and bundles see the following docs:

- plugins

    [Test::Stream::Plugin](https://metacpan.org/pod/Test::Stream::Plugin) - Provides tools to help write plugins.

- bundles

    [Test::Stream::Bundle](https://metacpan.org/pod/Test::Stream::Bundle) - Provides tools to help write bundles.

## EXPLANATION AND HISTORY

[Test::Stream](https://metacpan.org/pod/Test::Stream) has learned from [Test::Builder](https://metacpan.org/pod/Test::Builder). For a time it was common for
people to write `Test::*` tools that bundled other `Test::*` tools with them
when loaded. For a short time this seemed like a good idea. This was quickly
seen to be a problem when people wanted to use features of multiple testing
tools that both made incompatible assumptions about other modules you might
want to load.

[Test::Stream](https://metacpan.org/pod/Test::Stream) does not recreate this wild west approach to testing tools and
bundles. [Test::Stream](https://metacpan.org/pod/Test::Stream) recognises the benefits of bundles, but provides a
much more sane approach. Bundles and Tools are kept separate, this way you can
always use tools without being forced to adopt the authors ideal bundle.

# ENVIRONMENT VARIABLES

This is a list of environment variables Test::Stream looks at:

- TS\_FORMATTER="Foo"
- TS\_FORMATTER="+Foo::Bar"

    This can be used to set the output formatter. By default
    [Test::Stream::Formatter::TAP](https://metacpan.org/pod/Test::Stream::Formatter::TAP) is used.

    Normally 'Test::Stream::Formatter::' is prefixed to the value in the
    environment variable:

        $ TS_FORMATTER='TAP' perl test.t     # Use the Test::Stream::Formatter::TAP formatter
        $ TS_FORMATTER='Foo' perl test.t     # Use the Test::Stream::Formatter::Foo formatter

    If you want to specify a full module name you use the '+' prefix:

        $ TS_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

- TS\_KEEP\_TEMPDIR=1

    Some IPC drivers make use of temporary directories, this variable will tell
    Test::Stream to keep the directory when the tests are complete.

- TS\_LB\_PATH="./:./lib/:..."

    This allows you to provide paths where Test::Stream will search for project
    specific bundles. These paths are NOT added to `@INC`.

- TS\_MAX\_DELTA=25

    This is used by the [Test::Stream::Plugin::Compare](https://metacpan.org/pod/Test::Stream::Plugin::Compare) plugin. This specifies the
    max number of differences to show when data structures do not match.

- TS\_TERM\_SIZE=80

    This is used to set the width of the terminal. This is used when building
    tables of diagnostics. The default is 80, unless [Term::ReadKey](https://metacpan.org/pod/Term::ReadKey) is installed
    in which case the value is determined dynamically.

- TS\_WORKFLOW=42
- TS\_WORKFLOW="foo"

    This is used by the [Test::Stream::Plugin::Spec](https://metacpan.org/pod/Test::Stream::Plugin::Spec) plugin to specify which test
    block should be run, only the specified block will be run.

- TS\_RAND\_SEED=44523

    This only works when used with the [Test::Stream::Plugin::SRand](https://metacpan.org/pod/Test::Stream::Plugin::SRand) plugin. This
    lets you specify the random seed to use.

- HARNESS\_ACTIVE

    This is typically set by [TAP::Harness](https://metacpan.org/pod/TAP::Harness) and other harnesses. You should not
    need to set this yourself.

- HARNESS\_IS\_VERBOSE

    This is typically set by [TAP::Harness](https://metacpan.org/pod/TAP::Harness) and other harnesses. You should not
    need to set this yourself.

- NO\_TRACE\_MASK=1

    This variable is specified by [Trace::Mask](https://metacpan.org/pod/Trace::Mask). Test::Stream uses the
    [Trace::Mask](https://metacpan.org/pod/Trace::Mask) specification to mask some stack frames from traces generated by
    [Trace::Mask](https://metacpan.org/pod/Trace::Mask) compliant tools. Setting this variable will force a full stack
    trace whenever a trace is produced.

# SOURCE

The source code repository for Test::Stream can be found at
`http://github.com/Test-More/Test-Stream/`.

# MAINTAINERS

- Chad Granum &lt;exodist@cpan.org>

# AUTHORS

- Chad Granum &lt;exodist@cpan.org>

# COPYRIGHT

Copyright 2015 Chad Granum &lt;exodist7@gmail.com>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://www.perl.com/perl/misc/Artistic.html`
