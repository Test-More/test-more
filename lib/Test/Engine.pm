package Test::Engine;
use strict;
use warnings;

our %ENGINES = (
    Legacy => ['Test::Engine::Legacy', 'Test/Engine/Legacy.pm'],
);

my $ENGINE_NAME;
my $ENGINE;
my $LOADED;

sub import {
    my $class = shift;
    my ($method, @args) = @_;
    return unless $method;
    $class->$method(@args);
}

sub set_engine {
    my $class = shift;
    my ($name) = @_;

    if ($ENGINE_NAME) {
        return if $ENGINE_NAME eq $name;
        require Carp;
        Carp::confess("Could not load engine '$name', engine '$ENGINE_NAME' already loaded.");
    }

    my $spec = $ENGINES{$name};
    if (!$spec) {
        require Carp;
        Carp::confess("'$name' is not a known Test::Engine engine.");
    }
    my ($pkg, $file) = @$spec;
    require $file;

    $ENGINE_NAME = $name;
    $ENGINE = $pkg->files;

    return unless $LOADED;

    for my $module (keys %$LOADED) {
        $class->verify($module, $LOADED->{$module});
    }
}

sub get_engine_name {
    return $ENGINE_NAME if $ENGINE_NAME;
    my $class = shift;
    $class->_default;
    return $ENGINE_NAME;
}

sub get_engine {
    return $ENGINE if $ENGINE;
    my $class = shift;
    $class->_default;
    return $ENGINE;
}

sub _default {
    my $class = shift;
    my $name = $ENV{PERL_TEST_ENGINE} || 'Legacy';
    $class->set_engine($name);
}

sub load {
    my $class = shift;
    my ($module) = @_;
    my $engine = $class->get_engine;
    my $file = $engine->{$module};
    require $file;
}

sub verify {
    my $class = shift;
    my ($module, $file) = @_;

    # Validate later when we specify an engine.
    if (!$ENGINE_NAME) {
        $LOADED ||= {};
        $LOADED->{$module} = $file;
        return;
    }

    my $engine = $class->get_engine;

    # Not a perfect check, but good enough?
    # Problem is __FILE__ includes the full path, not just the part we care about.
    # We could also try stripping @INC paths from file, but I am worried abotu
    # performance there.
    my $required = $engine->{$module};
    return if $required && $file =~ m/\Q$required\E$/;

    require Carp;
    Carp::confess("Refusing to load '$module' in accordance with engine '$ENGINE_NAME' policy.")
        unless $required;

    Carp::confess("Something loaded the package '$module' via '$file', but engine '$ENGINE_NAME' specifies that it should load via '$required'.");
}

1;

=pod

=encoding UTF-8

=head1 NAME

Test::Engine - Pluggable Engines for Test::Builder based tools

=head1 DESCRIPTION

This module makes it possible to implement replacements for Test::Builder that
can still make use of the rich ecosystem. Using this system avoids breaking
anything already in the wild using Test::Builder.

Test::Builder is at the heart of a rich test ecosystem. The problem is that The
original design of Test::Builder is fundamentally flawed, leading to numerous
undesirable results that only get worse over time as the Test ecosystem grows
ever larger.

Things are further complicated by mutually exclusive goals. Some people want a
Test::Builder that provides more and better features for building Test::*
modules. Others want to simplify things in order to focus purely on performance
with little regard for interoperability. Some people want to avoid breaking
things at all costs.

Using this system, the old Test::Builder, Test::More, Test::Simple,
Test::Tester, and Test::Builder::Tester code have been moved as-is to what is
called the 'Legacy' engine. This engine is used by default in any tool that
does not request a specific engine. To this end nothing should break, as the
default is to do what has always been done.

Anyone who wants to may develop an alternative engine. For example the people
who do not care about interoperability may add one like Test::Engine::Fast
which simply implements Test::More and Test::Simple in a stand-alone way.
Anything that only uses Test::More can use this engine for performance. Such an
engine could easily be added to core for use in the perl test suite (even by
default).

For people who care about the ecosystem they can develop a new engine that is
backwords compatible for most libraries, but adds or changes anything they feel
must change to build a better ecosystem. This allows for improvements that
still work with most existing tools.

=head1 RECOMMENDED ENGINES

At the moment there is only one working engine, that is 'Legacy'. Ultimately
the goal is to have 3 recommended/supported engines in Test-Simple itself. The
'Legacy' engine which will be locked to all changes except critical bug fixes.
We will also be looking for a 'Fast' engine for use when you just want
Test::More, and you want it fast. Finally we will be looking for a 'Modern'
engine, which brings Test::Builder and its ecosystem into a new era.

Anyone is free to write any type of engine they want, however to avoid
fracturing the ecosystem too much, we will only ever recommend 'Legacy', a fast
variant, and a modern variant.

=head2 THE LIST

=over 4

=item Legacy

This is the legacy engine. This engine will never be replaced or removed.
Building tools against this engine means they will work even in older versions
of the Test-Simple distribution. If you want your tool to work on 5.6, or 5.8
without needing to upgrade Test-Simple, this is the engine for you.

The downside is that it will never progress past what it is now. It is
change-locked so that only critical bugfixes will be allowed in moving forward.

See: L<Test::Engine::Lengacy>, L<Test::Builder::Legacy>, L<Test::More::Legacy>.

=item Fast Engine

There is currently no recommended engine for this slot.

=item Modern Engine

There is currently no recommended engine for this slot.

=back

=head1 SPECIFYING AN ENGINE

There is an environment variable C<$ENV{PERL_TEST_ENGINE}> which should be set
to the name of the engine to use. In absense of code requesting a specific
engine, this variable becomes the new default replacing 'Legacy'.

If a tool absolutely requires a specific engine it may specify such in code.
This is important to ensure it fails early if someone tries to use it with an
incompatible engine. It also serves to override the default if it is loaded
first and other used tools do not care what engine is used. Please note, you
should never directly require the Legacy engine as many engines try to provide
a compatible API.

    use Test::Engine set_engine => 'EngineName';

=head1 AUTHORING AN ENGINE

An engine is a very simple:

    package Test::Engine::MyEngine; # Must be Test::Engine::NAME

    sub files {
        'Test::Builder' => 'MyEngine/Builder.pm',   # Specify our own file to define the Test::Builder namespace
        'Test::More'    => 'MyEngine/More.pm',      # Specify our own file to define the Test::More namespace
        'Test::Simple'  => 'Test/Simple/Legacy.pm', # Use the legacy Test::Simple implementation
        'Test::Tester'  => undef,                   # Refuse to load Test::Tester in this engine

        'Test::Builder::Tester' => undef,           # Refuse to load Test::Builder::Tester in this engine
    }


MyEngine/Builder.pm

    # Specify this package name for indexing
    package MyEngine::Builder;

    # Specify the Test::Builder namespace so we actually define it
    # The newline and indentation is done to avoid indexing this namespace in
    # your dist, which is critically important.
    package
        Test::Builder;

    ... Your implementation here ...

You can then use your implementation in any number of ways:

    use Test::Engine set_engine => 'MyEngine';
    use Test::Builder;

or

    use MyEngine::Builder;

or set the PERL_TEST_ENGINE environment variable to 'MyEngine' then:

    use Test::Builder;

=head2 FAST EXAMPLE

Test/Engine/Fast.pm

    package Test::Engine::Fast

    sub files {
        'Test::Simple' => 'Test/Fast/Simple.pm',
        # Refuse to load Test::More, Test::Builder, Test::Tester, and
        # Test::Builder::Tester
    }

    1

Test/Engine/Fast/Simple.pm

    package Test::Engine::Fast::Simple;

    package
        Test::Simple;

    sub import {
        my $class = shift;
        ... plan and exports ...
    }

    my $num = 1;

    sub ok($;$) {
        my ($bool, $name) = @_;

        my $out = $bool ? "ok " : 'not ok ';
        $out .= $num++;
        $out .= " - $name" if $name;
        print "$out\n";

        unless ($bool) {
            my @caller = caller;
            $name ||= 'unnamed';
            print STDERR "# Test '$name' failed at file $caller[1] line $caller[2]\n";
        }

        return $bool ? 1 : 0;
    }

    1;

=head1 KNOWN ENGINES

This is just a list of known engines. This list does not make any
recommendations or judgements on the engines of any kind.

=over 4

=item Legacy

The legacy engine, bundled with Test-Simple

=item Stream

L<Test::Stream> is an engine with a focus on backwords compatability, and
improved capabilities. It is a contendor for the 'Modern' engine
recommendation.

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
