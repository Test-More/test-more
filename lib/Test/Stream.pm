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

sub default { '-Default' }

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

    while (my $arg = shift @_) {
        my $type = reftype($arg) || "";

        if ($type eq 'CODE') {
            push @order => $arg;
            next;
        }

        if ($arg =~ m/^-(.*)$/) {
            my $pkg = "Test::Stream::Bundle::$1";
            my $file = pkg_to_file($pkg);
            eval { require $file; 1 } || croak "Could not load Test::Stream bundle '$pkg': $@";
            unshift @_ => $pkg->plugins;
            next;
        }

        my $val = (@_ && ref $_[0]) ? shift @_ : [];

        if ($arg =~ m/^\+(.*)$/) {
            $arg = $1;
        }
        else {
            $arg = __PACKAGE__ . '::Plugin::' . $arg;
        }
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

        my $import = $args{$arg};
        my $mod  = $arg;
        my $file = pkg_to_file($mod);
        eval { require $file; 1 } || croak "Could not load Test::Stream plugin '$arg' ($mod): $@";

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

If you are not already familiar with testing you should check out
L<Test::Stream::Manual::BeginnerTutorial>. If you know your way around testing
and want to know what Test::Stream can provide you should see
L<Test::Stream::Manual>. Finally, if you want to write new testing
tools using L<Test::Stream> you should take a look at
L<Test::Stream::Manual::Tooling>.

=head1 DESCRIPTION

B<This is not a drop-in replacement for Test::More>.

L<Test::Stream> is a framework designed to replace L<Test::Builder> as the new
base upon which testing tools should be built. This module is intended to be
the primary interface for people writing tests.

Loading L<Test::Stream> without arguments will load the
L<Test::Stream::Bundle::Default> plugin bundle. The default bundle will provide
you with functionality very close, and in I<most> cases identical to what
L<Test::More> provides. Some functionality has been moved, removed, added,
renamed, this decision was made since adopting Test::Stream is not mandatory
and already requires effort.

=head1 SYNOPSIS

    use Test::Stream;

    ok(1, "1 is true");
    is('xxx', 'xxx', "compare 2 string");
    is_deeply($thing1, $thing2, "these structures are the same");
    ...

    done_testing;

See L<Test::Stream::Bundle::Default> for a list of everything loaded by default.

=head1 MANUAL

L<Test::Stream::Manual> is a good place to start when searching for
documentation.

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
