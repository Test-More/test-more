package Test::Stream;
use strict;
use warnings;
use vars qw/$VERSION/;

$Test::Stream::VERSION = '1.302016';
$VERSION = eval $VERSION;

use Carp qw/croak/;
use Scalar::Util qw/reftype/;

use Test::Stream::Sync;

use Test::Stream::Util qw/try pkg_to_file/;

our $LOAD_INTO;

sub default {
    croak "No plugins or bundles specified, did you forget to add '-V1'?"
}

sub import {
    my $class = shift;
    my @caller = caller;

    push @_ => $class->default unless @_;

    $class->load(\@caller, @_);

    1;
}

sub load {
    my $class = shift;
    my $caller = shift;

    my @order;
    my %args;
    my %skip;

    while (my $arg = shift @_) {
        my $type = reftype($arg) || "";

        if ($type eq 'CODE') {
            push @order => $arg;
            next;
        }

        # Strip off the '+', which may be combined with ':' or '-' at the
        # start.
        my $full = ($arg =~ s/^([!:-]?)\+/$1/) ? 1 : 0;

        # Disallowed plugin
        if ($arg =~ m/^!(.*)$/) {
            my $pkg = $full ? $1 : "Test::Stream::Plugin::$1";
            $skip{$pkg}++;
            next;
        }

        # Bundle
        if ($arg =~ m/^-(.*)$/) {
            my $pkg = $full ? $1 : "Test::Stream::Bundle::$1";
            my $file = pkg_to_file($pkg);
            require $file;
            unshift @_ => $pkg->plugins;
            next;
        }

        # Local Bundle
        if ($arg =~ m/^:(.*)$/) {
            my $pkg = $full ? $1 : "Test::Stream::Bundle::$1";
            my $file = pkg_to_file($pkg);

            local @INC = (
                ($ENV{TS_LB_PATH} ? split(':', $ENV{TS_LB_PATH}) : ()),
                't/lib',
                'lib',
                sub {
                    my ($me, $fname) = @_;
                    return unless $fname eq $file;
                    die "Could not load LOCAL PROJECT bundle '$pkg' (Do you need to set TS_LB_PATH?)\n";
                },
                @INC,
            );

            require $file;
            unshift @_ => $pkg->plugins;
            next;
        }

        if ($arg =~ m/^[a-z]/) {
            my $method = "opt_$arg";

            die "'$arg' is not a valid option for '$class' (Did you intend to use the '" . ucfirst($arg) . "' plugin?) at $caller->[1] line $caller->[2].\n"
                unless $class->can($method);

            $class->$method(list => \@_, order => \@order, args => \%args, skip => \%skip);
            next;
        }

        # Load the plugin
        $arg = 'Test::Stream::Plugin::' . $arg unless $full;

        # Get the value
        my $val;

        # Arg is specified
        $val = shift @_ if @_ && (ref($_[0]) || ($_[0] && $_[0] eq '*'));

        # Special Cases
        $val = $val eq '*' ? ['-all'] : [$val]
            if defined($val) && !ref($val);

        # Make sure we only list it in @order once.
        push @order => $arg unless $args{$arg};

        # Override any existing value, last wins.
        $args{$arg} = $val if defined $val;
    }

    for my $arg (@order) {
        my $type = reftype($arg) || "";
        if ($type eq 'CODE') {
            $arg->($caller);
            next;
        }

        next if $skip{$arg};

        my $import = $args{$arg};
        my $mod  = $arg;

        my $file = pkg_to_file($mod);
        unless (eval { require $file; 1 }) {
            my $error = $@ || 'unknown error';
            my $file = __FILE__;
            my $line = __LINE__ - 3;
            $error =~ s/ at \Q$file\E line $line.*//;
            croak "Could not load Test::Stream plugin '$arg': $error";
        }

        if ($mod->can('load_ts_plugin')) {
            $mod->load_ts_plugin($caller, @$import);
        }
        elsif (my $meta = Test::Stream::Exporter::Meta->get($mod)) {
            Test::Stream::Exporter::export_from($mod, $caller->[0], $import);
        }
        elsif (@$import) {
            croak "Module '$mod' does it implement 'load_ts_plugin()', nor does it export using Test::Stream::Exporter."
        }
    }

    Test::Stream::Sync->loaded(1);
}

sub opt_class {
    shift;
    my %params = @_;
    my $list = $params{list};
    my $args = $params{args};
    my $order = $params{order};

    my $class = shift @$list;

    push @{$params{order}} => 'Test::Stream::Plugin::Class'
        unless $args->{'Test::Stream::Plugin::Class'};

    $args->{'Test::Stream::Plugin::Class'} = [$class];
}

sub opt_skip_without {
    shift;
    my %params = @_;
    my $list = $params{list};
    my $args = $params{args};
    my $order = $params{order};

    my $class = shift @$list;

    push @{$params{order}} => 'Test::Stream::Plugin::SkipWithout'
        unless $args->{'Test::Stream::Plugin::SkipWithout'};

    $args->{'Test::Stream::Plugin::SkipWithout'} ||= [];
    push @{$args->{'Test::Stream::Plugin::SkipWithout'}} => $class;
}

sub opt_srand {
    shift;
    my %params = @_;
    my $list = $params{list};
    my $args = $params{args};
    my $order = $params{order};

    my $seed = shift @$list;

    push @{$params{order}} => 'Test::Stream::Plugin::SRand'
        unless $args->{'Test::Stream::Plugin::SRand'};

    $args->{'Test::Stream::Plugin::SRand'} = [$seed];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream - Experimental successor to Test::More and Test::Builder.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 ***READ THIS FIRST***

B<This is not a drop-in replacement for Test::More>.

Adoption of L<Test::Stream> instead of continuing to use L<Test::More> is a
choice. Liberty has been taken to make significant API changes. Replacing C<use
Test::More;> with C<use Test::Stream;> will not work for more than the most
trivial of test files.

See L<Test::Stream::Manual::FromTestBuilder> if you are coming from
L<Test::More> or L<Test::Simple> and want a quick translation.

=head1 MANUAL

TODO: Manual

=head1 DESCRIPTION

This is the primary interface for loading L<Test::Stream> based tools. This
module is responsible for loading bundles and plugins for the tools you want.
L<Test::Stream::Bundle::V1> is the suggested bundle for those just starting
out.

=head1 SYNOPSIS

    use Test::Stream -V1;

    ok(1, "This is a pass");
    ok(0, "This is a fail");

    is("x", "x", "These strings are the same");
    is($A, $B, "These 2 structures match exactly");

    like('x', qr/x/, "This string matches this pattern");
    like($A, $B, "These structures match where it counts");

    done_testing;

=head1 IMPORTANT NOTE

C<use Test::Stream;> will fail. You B<MUST> specify at least 1 bundle or
plugin. If you do not specify any then none would be imported and that is
obviously not what you want. If you are new to Test::Stream then you should
probably start with the '-V1' argument, which loads
L<Test::Stream::Bundle::V1>. The V1 bundle provides the most commonly
needed tools.

=head2 WHY NOT MAKE A DEFAULT BUNDLE OR SET OF PLUGINS?

Future Proofing. If we decide in the future that a specific plugin or tool is
harmful we would like to be able to remove it. Making a tool part of the
default set will effectively make it unremovable as doing so would break
compatability. To solve this problem we have the 'Core#' bundle system.

'V1' is the first bundle, and the recommended one for now. If the future tells
us that parts of 'V1' are harmful, or that we need more than what is currently
provided, we can release 'V2'. 'V1' will not be changed in a backwords
incompatible way, so nothing breaks, but everyone else can move on and start
using 'V2' in new code.

The number following the 'V' prefix should correspond to a major version
number. This means that 'V1' is provided with Test::Stream 1.X. V2
will prompt a 2.X release and so on.

=head1 PLUGINS, BUNDLES, AND OPTIONS

L<Test::Stream> tools should be created as plugins. This is not enforced,
nothing prevents you from writing L<Test::Stream> tools that are not plugins.
However writing your tool as a plugin will help your module to play well with
other tools. Writing a plugin also makes it easier for you to create private or
public bundles that reduce your boilerplate.

Bundles are very simple. At its core a bundle is simply a list of other
bundles, plugins, and arguments to those plugins. Much like hash declaration a
'last wins' approach is used; if you load 2 bundles that share a plugin with
different arguments, the last set of arguments wins.

Plugins and bundles can be distinguished easily:

    use Test::Stream(
        '-V1',                          # Bundle ('-')
        ':Project',                     # Project specific bundle (':')
        'MyPlugin',                     # Plugin name (no prefix)
        '+Fully::Qualified::Plugin',    # (Plugin in unusual path)
        'SomePlugin' => ['arg1', ...],  # (Plugin with args)
        '!UnwantedPlugin',              # Do not load this plugin
        'WantEverything' => '*',        # Load the plugin with all options
        'option' => ...,                # Option to the loader (Test::Stream)
    );

Explanation:

=over 4

=item '-V1',

The C<-> prefix indicates that the specified item is a bundle. Bundles live in
the C<Test::Stream::Bundle::> namespace. Each bundle is an independant module.
You can specify any number of bundles, or none at all.

=item ':Project'

The ':' prefix indicates we are loading a project specific bundle, which means
the module must be located in C<t/lib/>, C<lib/>, or the paths provided in the
C<TS_LB_PATH> environment variable. In the case of ':Project' it will look for
C<Test/Stream/Bundle/Project.pm> in C<TS_LB_PATH>, C<t/lib/>, then C<lib/>.

This is a good way to create bundles useful to your project, but not really
worth putting on CPAN.

=item 'MyPlugin'

Arguments without a prefix are considered to be plugin names. Plugins are
assumed to be in C<Test::Stream::Plugin::>, which is prefixed automatically for
you.

=item '+Fully::Qualified::Plugin'

If you write a plugin, but put it in a non-standard namespace, you can use the
fully qualified plugin namespace prefixed by '+'. Apart from the namespace
treatment there is no difference in how the plugin is loaded or used.

=item 'SomePlugin' => \@ARGS

Most plugins provide a fairly sane set of defaults when loaded. However some
provide extras you need to request. When loading a plugin directly these would
be the import arguments. If you plugin is followed by an arrayref the ref
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

=item '!UnwantedPlugin'

This will blacklist the plugin so that it will not be used. The blacklist will
block the plugin regardless of where it is listed. The blacklist only effects
the statement in which it appears; if you load Test::Stream twice, the
blacklist will only apply to the load in which it appears. You cannot override
the blacklist items.

=item 'WantEverything' => '*'

This will load the plugin with all options. The '*' gets turned into
C<['-all']> for you.

=item 'option' => ...

Uncapitalized options without a C<+>, C<->, or C<:> prefix are reserved for use
by the loader. Loaders that subclass Test::Stream can add options of their own.

To define an option in your subclass simply add a C<sub opt_NAME()> method. The
method will recieve several arguments:

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

=back

=head2 AVAILABLE OPTIONS

=over 4

=item class => $CLASS

Shortcut for the L<Test::Stream::Plugin::Class> plugin.

=item skip_without => $MODULE

=item skip_without => 'v5.008'

=item skip_without => [$MODULE => $VERSION]

Shortcup for the L<Test::Stream::Plugin::SkipWithout> plugin. Unlike normal
specification of a plugin, this APPENDS arguments. This one can be called
several time and the arguments will be appended.

B<Note:> specifying 'SkipWithout' the normal way after a call to 'skip_without'
will wipe out the argument that have accumulated so far.

=item srand => $SEED

Shortcut to set the random seed.

=back

=head2 SEE ALSO

For more about plugins and bundles see the following docs:

=over 4

=item plugins

L<Test::Stream::Plugin> - Provides tools to help write plugins.

=item bundles

L<Test::Stream::Bundle> - Provides tools to help write bundles.

=back

=head2 EXPLANATION AND HISTORY

L<Test::Stream> has learned from L<Test::Builder>. For a time it was common for
people to write C<Test::*> tools that bundled other C<Test::*> tools with them
when loaded. For a short time this seemed like a good idea. This was quickly
seen to be a problem when people wanted to use features of multiple testing
tools that both made incompatible assumptions about other modules you might
want to load.

L<Test::Stream> does not recreate this wild west approach to testing tools and
bundles. L<Test::Stream> recognises the benefits of bundles, but provides a
much more sane approach. Bundles and Tools are kept seperate, this way you can
always use tools without being forced to adopt the authors ideal bundle.

=head1 ENVIRONMENT VARIABLES

This is a list of environment variables Test::Stream looks at:

=over 4

=item TS_FORMATTER="Foo"

=item TS_FORMATTER="+Foo::Bar"

This can be used to set the output formatter. By default
L<Test::Stream::Formatter::TAP> is used.

Normally 'Test::Stream::Formatter::' is prefixed to the value in the
environment variable:

    $ TS_FORMATTER='TAP' perl test.t     # Use the Test::Stream::Formatter::TAP formatter
    $ TS_FORMATTER='Foo' perl test.t     # Use the Test::Stream::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ TS_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item TS_KEEP_TEMPDIR=1

Some IPC drivers make use of temporary directories, this variable will tell
Test::Stream to keep the directory when the tests are complete.

=item TS_LB_PATH="./:./lib/:..."

This allows you to provide paths where Test::Stream will search for project
specific bundles. These paths are NOT added to C<@INC>.

=item TS_MAX_DELTA=25

This is used by the L<Test::Stream::Plugin::Compare> plugin. This specifies the
max number of differences to show when data structures do not match.

=item TS_TERM_SIZE=80

This is used to set the width of the terminal. This is used when building
tables of diagnostics. The default is 80, unless L<Term::ReadKey> is installed
in which case the value is determined dynamically.

=item TS_WORKFLOW=42

=item TS_WORKFLOW="foo"

This is used by the L<Test::Stream::Plugin::Spec> plugin to specify which test
block should be run, only the specified block will be run.

=item TS_RAND_SEED=44523

This only works when used with the L<Test::Stream::Plugin::SRand> plugin. This
lets you specify the random seed to use.

=item HARNESS_ACTIVE

This is typically set by L<TAP::Harness> and other harnesses. You should not
need to set this yourself.

=item HARNESS_IS_VERBOSE

This is typically set by L<TAP::Harness> and other harnesses. You should not
need to set this yourself.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
