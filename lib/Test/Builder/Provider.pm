package Test::Builder::Provider;
use strict;
use warnings;

use Test::Builder;
use Carp qw/croak/;
use Scalar::Util qw/blessed reftype set_prototype/;
use B();

my %SIG_MAP = (
    '$' => 'SCALAR',
    '@' => 'ARRAY',
    '%' => 'HASH',
    '&' => 'CODE',
);

my $ID = 1;

sub import {
    my $class = shift;
    my $caller = caller;

    $class->export_into($caller, @_);
}

sub export_into {
    my $class = shift;
    my ($dest, @sym_list) = @_;

    my %subs;

    my $meta = $class->make_provider($dest);

    $subs{TB}      = \&find_builder;
    $subs{builder} = \&find_builder;
    $subs{anoint}  = \&anoint;
    $subs{import}  = \&provider_import;
    $subs{provide} = $class->_build_provide($dest, $meta);
    $subs{export}  = $class->_build_export($dest, $meta);

    $subs{provide_nests} = sub { $subs{provide}->($_,    undef, nest => 1) for @_ };
    $subs{provide_nest}  = sub { $subs{provide}->($_[0], $_[1], nest => 1)        };
    $subs{gives}         = sub { $subs{provide}->($_,    undef, give => 1) for @_ };
    $subs{give}          = sub { $subs{provide}->($_[0], $_[1], give => 1)        };
    $subs{provides}      = sub { $subs{provide}->($_)                      for @_ };

    @sym_list = keys %subs unless @sym_list;

    my %seen;
    for my $name (grep { !$seen{$_}++ } @sym_list) {
        no strict 'refs';
        my $ref = $subs{$name} || $class->can($name);
        croak "$class does not export '$name'" unless $ref;
        *{"$dest\::$name"} = $ref ;
    }

    1;
}

sub make_provider {
    my $class = shift;
    my ($dest) = @_;

    my $meta = $dest->can('TB_PROVIDER_META') ? $dest->TB_PROVIDER_META : undef;

    unless ($meta) {
        $meta = {refs => {}, attrs => {}};
        no strict 'refs';
        $meta->{export} = \@{"$dest\::EXPORT"};
        *{"$dest\::TB_PROVIDER_META"} = sub { $meta };
    }

    return $meta;
}

sub _build_provide {
    my $class = shift;
    my ($dest, $meta) = @_;

    $meta->{provide} ||= sub {
        my ($name, $ref, %params) = @_;

        croak "$dest already provides or gives '$name'"
            if $meta->{attrs}->{$name};

        croak "The second argument to provide() must be a ref, got: $ref"
            if $ref && !ref $ref;

        $ref ||= $dest->can($name);
        croak "$dest has no sub named '$name', and no ref was given"
            unless $ref;

        my $attrs = {%params, package => $dest, name => $name};
        $meta->{attrs}->{$name} = $attrs;

        # Stupid Legacy! This can go away when https://github.com/Ovid/test--most/pull/9 is merged.
        push @{$meta->{export}} => $name;

        # If this is just giving, or not a coderef
        return $meta->{refs}->{$name} = $ref if $params{give} || reftype $ref ne 'CODE';

        bless $ref, $class;

        my $o_name = B::svref_2object($ref)->GV->NAME;
        if ($o_name && $o_name ne '__ANON__') { #sub has a name
            $meta->{refs}->{$name} = $ref;
        }
        else {
            # Voodoo....
            # Insert an anonymous sub, and use a trick to make caller() think its
            # name is this string, which tells us how to find the thing that was
            # actually called.
            my $globname = __PACKAGE__ . '::__ANON' . ($ID++) . '__';

            my $code = sub {
                no warnings 'once';
                local *__ANON__ = $globname; # Name the sub so we can find it for real.
                $ref->(@_);
            };

            # The prototype on set_prototype blocks this usage, even though it
            # is valid. This is why we use the old-school &func() call.
            # Oh the irony.
            my $proto = prototype($ref);
            &set_prototype($code, $proto) if $proto;

            $meta->{refs}->{$name} = bless $code, $class;

            no strict 'refs';
            *$globname = $code;
            *$globname = $attrs;
        }
    };

    return $meta->{provide};
}

sub _build_export {
    my $class = shift;
    my ($dest, $meta) = @_;

    return sub {
        my $class = shift;
        my ($caller, @args) = @_;

        my (%no, @list);
        for my $thing (@args) {
            if ($thing =~ m/^!(.*)$/) {
                $no{$1}++;
            }
            else {
                push @list => $thing;
            }
        }

        my (%export, %export_ok);
        {
            no strict 'refs';
            %export    = map {($_ => 1)} @{"$class\::EXPORT"};
            %export_ok = map {($_ => 1)} @{"$class\::EXPORT_OK"}, @{"$class\::EXPORT"};
        }
        #warn "package '$class' uses \@EXPORT and/or \@EXPORT_OK, this is deprecated since '$dest' is no longer a subclass of 'Exporter'\n"
        #    if keys %export_ok;

        unless(@list) {
            my %seen;
            #@list = grep { !($no{$_} || $seen{$_}++) } keys(%{$meta->{refs}}), keys(%export);
            # Stupid Legacy! This can go away when https://github.com/Ovid/test--most/pull/9 is merged.
            @list = grep { !($no{$_} || $seen{$_}++) } keys(%export);
        }
        for my $name (@list) {
            if ($name =~ m/^(\$|\@|\%)(.*)$/) {
                my ($sig, $sym) = ($1, $2);

                croak "$class does not export '$name'"
                    unless ($meta->{refs}->{$sym} && reftype $meta->{refs}->{$sym} eq $SIG_MAP{$sig})
                        || ($export_ok{$name});

                no strict 'refs';
                *{"$caller\::$sym"} = $meta->{refs}->{$name} || *{"$class\::$sym"}{$sig}
                    || croak "'$class' has no symbol named '$name'";
            }
            else {
                croak "$class does not export '$name'"
                    unless $meta->{refs}->{$name} || $export_ok{$name};

                no strict 'refs';
                *{"$caller\::$name"} = $meta->{refs}->{$name} || $class->can($name)
                    || croak "'$class' has no sub named '$name'";
            }
        }
    };
}

sub provider_import {
    my $class = shift;
    my $caller = caller;

    $class->anoint($caller);
    $class->before_import(\@_) if $class->can('before_import');
    $class->export($caller, @_);
    $class->after_import(@_)   if $class->can('after_import');

    1;
}

sub find_builder {
    my $trace = Test::Builder->trace_test;

    if ($trace && $trace->{report}) {
        my $pkg = $trace->{package};
        return $pkg->TB_INSTANCE
            if $pkg && $pkg->can('TB_INSTANCE');
    }

    return Test::Builder->new;
}

sub anoint { Test::Builder->anoint($_[1], $_[0]) };

1;

=head1 NAME

Test::Builder::Provider - Helper for writing testing tools

=head1 TEST COMPONENT MAP

  [Test Script] > [Test Tool] > [Test::Builder] > [Test::Bulder::Stream] > [Result Formatter]
                       ^
                  You are here

A test script uses a test tool such as L<Test::More>, which uses Test::Builder
to produce results. The results are sent to L<Test::Builder::Stream> which then
forwards them on to one or more formatters. The default formatter is
L<Test::Builder::Fromatter::TAP> which produces TAP output.

=head1 DESCRIPTION

This package provides you with tools to write testing tools. It makes your job
of integrating with L<Test::Builder> and other testing tools much easier.

=head1 SYNOPSYS

Instead of use L<Exporter> or other exporters, you can use convenience
functions to define exports on the fly.

    package My::Tester
    use strict;
    use warnings;

    use Test::Builder::Provider;

    sub before_import {
        my $class = shift;
        my ($import_args_ref) = @_;

        ... Modify $import_args_ref ...
        # $import_args_ref should contain only what you want to pass as
        # arguments into export().
    }

    sub after_import {
        my $class = shift;
        my @args = @_;

        ...
    }

    # Provide (export) an 'ok' function (the anonymous function is the export)
    provide ok => sub { builder()->ok(@_) };

    # Provide some of our package functions as test functions.
    provides qw/is is_deeply/;
    sub is { ... }
    sub is_deeply { ... };

    # Provide a 'subtests' function. Functions that accept a block like this
    # that may run other tests should be use provide_nest to mark them as
    # nested providers.
    provide_nest subtests => sub(&) { ... };

    # Provide a couple nested functions defined in our package
    provide_nests qw/subtests_alt subtests_xxx/;
    sub subtests_alt(&) { ... }
    sub subtests_xxx(&) { ... }

    # Export a helper function that does not produce any results (regular
    # export).
    give echo => sub { print @_ };

    # Same for multiple functions in our package:
    gives qw/echo_stdout echo_stderr/;
    sub echo_stdout { ... }
    sub echo_stderr { ... }

=head2 IN A TEST FILE

    use Test::More;
    use My::Tester;

    ok(1, "blah");

    is(1, 1, "got 1");

    subtests {
        ok(1, "a subtest");
        ok(1, "another");
    };

=head2 USING EXTERNAL EXPORT LIBRARIES

Maybe you like L<Exporter> or another export tool. In that case you still need
the 'provides' and 'provide_nests' functions from here to mark testing tools as
such.

This is also a quick way to update an old library, but you also need to remove
any references to C<$Test::Builder::Level> which is now deprecated.

    package My::Tester
    use strict;
    use warnings;

    use base 'Exporter';
    use Test::Builder::Provider qw/provides provide_nests/;

    our @EXPORT = qw{
        ok is is_deeply
        subtests subtests_alt subtests_xxx
        echo echo_stderr echo stdout
    };

    # *mark* the testing tools
    provides qw/ok is is_deeply/;
    sub ok { builder()->ok(@_) }
    sub is { ... }
    sub is_deeply { ... };

    # *mark* the nesting test tools
    provide_nests qw/subtests subtests_alt subtests_xxx/;
    sub subtests(&) { ... }
    sub subtests_alt(&) { ... }
    sub subtests_xxx(&) { ... }

    # No special marking needed for these as they do not produce results.
    sub echo { print @_ }
    sub echo_stdout { ... }
    sub echo_stderr { ... }

=head1 META-DATA

Importing this module will always mark your package as a test provider. It does
this by injecting a method into your package called 'TB_PROVIDER_META'. This
method simply returns the meta-data hash for your package.

To avoid this you can use 'require' instead of 'use', or you can use () in your import:

    # Load the module, but do not make this package a provider.
    require Test::Builder::Provider;
    use Test::Builder::Provider();

=head1 EXPORTS

All of these subs are injected into your package (unless you request a subset).

=over 4

=item my $tb = TB()

=item my $tb = builder()

Get the correct instance of L<Test::Builder>. Usually this is the instance used
in the test file calling a tool in your package. If no such instance can be
found the default Test::Builder instance will be used.

=item $class->anoint($target)

Used to mark the $target package as a test package that consumes your test
package for tools. This is done automatically for you if you use the default
'import' sub below.

=item $class->import()

=item $class->import(@list)

An import() function that exports your tools to any consumers of your class.

=item $class->export($dest)

=item $class->export($dest, @list)

Export the packages tools into the $dest package. @list me be specified to
restrict what is exported. Prefix any item in the list with '!' to prevent
exporting it.

=item provide $name

=item provide $name => sub { ... }

Provide a testing tool that will produce results. If no coderef is given it
will look for a coderef with $name in your package.

You may also use this to export refs of any type.

=item provides qw/sub1 sub2 .../

Like provide except you can specify multiple subs to export.

=item provide_nest $name

=item provide_nest $name => sub(&) { ... }

Like provide, but use on tools like subtests that accept a block of tests to be
run.

=item provide_nests qw/sub1 sub2 .../

Same as providesm, but used on nesting tools.

=item give $name

=item give $name => sub { ... }

Export a helper function that does not produce results.

=item gives qw/sub1 sub2 .../

Export helper functions.

=back

=head1 HOW DO I TEST MY TEST TOOLS?

See L<Test::Tester2>

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
