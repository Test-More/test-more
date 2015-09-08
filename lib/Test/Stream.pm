package Test::Stream;
use strict;
use warnings;
use vars qw/$VERSION/;

$Test::Stream::VERSION = '1.302009';
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

        # Load the plugin
        $arg = 'Test::Stream::Plugin::' . $arg unless $full;
        my $file = pkg_to_file($arg);
        unless (eval { require $file; 1 }) {
            my $error = $@ || 'unknown error';
            my $file = __FILE__;
            my $line = __LINE__ - 3;
            $error =~ s/ at \Q$file\E line $line.*//;
            croak "Could not load Test::Stream plugin '$arg': $error";
        }

        # Get the value
        my $val;

        # Arg is specified
        $val = shift @_ if @_ && (ref($_[0]) || ($_[0] && $_[0] eq '*'));

        # Fallback to no args
        $val = [] unless defined $val;

        # Special Cases
        $val = $val eq '*' ? ['-all'] : [$val]
            unless ref $val;

        # Make sure we only list it in @order once.
        push @order => $arg unless $args{$arg};

        # Override any existing value, last wins.
        $args{$arg} = $val;
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

=head1 PLUGINS AND BUNDLES

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
        '-V1',                       # Suggected bundle ('-')
        ':Project',                     # Preject specific bundle (':')
        'MyPlugin',                     # Plugin name (no prefix)
        '+Fully::Qualified::Plugin',    # (Plugin in unusual path)
        'SomePlugin' => ['arg1', ...],  # (Plugin with args)
        '!UnwantedPlugin',              # Do not load this plugin
        'WantEverything' => '*',        # Load the plugin with all options
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
