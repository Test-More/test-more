package Test::Stream::HashBase;
use strict;
use warnings;

use Test::Stream::HashBase::Meta;
use Test::Stream::Carp qw/confess croak/;
use Scalar::Util qw/blessed reftype/;

use Test::Stream::Exporter();

sub import {
    my $class = shift;
    my $caller = caller;

    $class->apply_to($caller, @_);
}

sub apply_to {
    my $class = shift;
    my ($caller, %args) = @_;

    # Make the calling class an exporter.
    my $exp_meta = Test::Stream::Exporter::Meta->new($caller);
    Test::Stream::Exporter->export_to($caller, 'import')
        unless $args{no_import};

    my $ab_meta = Test::Stream::HashBase::Meta->new($caller);

    my $ISA = do { no strict 'refs'; \@{"$caller\::ISA"} };

    if ($args{base}) {
        my ($base) = grep { $_->isa($class) } @$ISA;

        croak "$caller is already a subclass of '$base', cannot subclass $args{base}"
            if $base;

        my $file = $args{base};
        $file =~ s{::}{/}g;
        $file .= ".pm";
        require $file unless $INC{$file};

        my $pmeta = Test::Stream::HashBase::Meta->get($args{base});
        croak "Base class '$args{base}' is not a subclass of $class!"
            unless $pmeta;

        push @$ISA => $args{base};

        $ab_meta->subclass($args{base});
    }
    elsif( !grep { $_->isa($class) } @$ISA) {
        push @$ISA => $class;
        $ab_meta->baseclass();
    }

    $ab_meta->add_accessors(@{$args{accessors}})
        if $args{accessors};
}


# Note: There is no practical difference between always calling init() and
# checking ->can('init') when profiled.
sub init {}
sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless \%params, $class;
    $self->init;
    return $self;
}

sub new_debug {
    my $class = shift;
    my %params = @_;

    my $meta = Test::Stream::HashBase::Meta->get($class);
    my $fields = $meta->fields;

    for my $field (keys %params) {
        croak "$class has no accessor named '$field'"
            unless $fields->{$field};
    }

    my $self = bless \%params, $class;
    $self->init;
    return $self;
}

# If debugging is enabled use the slower, but validating new method.
if ($ENV{TEST_STREAM_DEBUG}) {
    no warnings 'redefine';
    *new = \&new_debug;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::HashBase - Base class for classes that use a hashref
of a hash.

=head1 SYNOPSIS

A class:

    package My::Class;
    use strict;
    use warnings;

    use Test::Stream::HashBase accessors => [qw/foo bar baz/];

    # Chance to initialize defaults
    sub init {
        my $self = shift;    # No other args
        $self->{+FOO} ||= "foo";
        $self->{+BAR} ||= "bar";
        $self->{+BAZ} ||= "baz";
    }

    sub print {
        print join ", " => map { $self->{$_} } FOO, BAR, BAZ;
    }

Subclass it

    package My::Subclass;
    use strict;
    use warnings;
    use Test::Stream::HashBase base => 'My::Class',    # subclass
        accessors                   => ['bat'];

    sub init {
        my $self = shift;

        # We get the constants from the base class for free.
        $self->{+FOO} ||= 'SubFoo';
        $self->{+BAT} || = 'bat';

        $self->SUPER::init();
    }

use it:

    package main;
    use strict;
    use warnings;
    use My::Class;

    my $one = My::Class->new(foo => 'MyFoo', bar => 'MyBar');

    # Accessors!
    my $foo = $one->foo;    # 'MyFoo'
    my $bar = $one->bar;    # 'MyBar'
    my $baz = $one->baz;    # Defaulted to: 'baz'

    # Setters!
    $one->set_foo('A Foo');
    $one->set_bar('A Bar');
    $one->set_baz('A Baz');

    # import constants:
    use My::Class qw/FOO BAR BAZ/;

    $one->{+FOO} = 'xxx';

=head1 DESCRIPTION

This package is used to generate classes based on hashrefs instead of
arrayrefs.  Using this class will give you a C<new()> method, as well as
generating accessors you request.  Generated accessors will be getters,
C<set_ACCESSOR> setters will also be generated for you. You also get constants
for each accessor (all caps) which return the key into the hash for that
accessor. Single inheritence is also supported.

=head1 METHODS

=head2 PROVIDED BY HASH BASE

=over 4

=item $it = $class->new(@VALUES)

Create a new instance using key/value pairs.

=item $it->import()

This import method is actually provided by L<Test::Stream::Exporter> and allows
you to import the constants generated for you.

=back

=head2 HOOKS

=over 4

=item $self->init()

This gives you the chance to set some default values to your fields. The only
argument is C<$self> with its indexes already set from the constructor.

=back

=head1 ACCESSORS

To generate accessors you list them when using the module:

    use Test::Stream::HashBase accessors => [qw/foo/];

This will generate the following subs in your namespace:

=over 4

=item import()

This will let you import the constants

=item foo()

Getter, used to get the value of the C<foo> field.

=item set_foo()

Setter, used to set the value of the C<foo> field.

=item FOO()

Constant, returs the field C<foo>'s key into the class hashref. This function
is also exported, but only when requested. Subclasses will also get this
function as a constant, not simply a method, that means it is copied into the
subclass namespace.

=back

=head1 SUBCLASSING

You can subclass an existing HashBase class.

    use Test::Stream::HashBase
        base      => 'Another::HashBase::Class',
        accessors => [qw/foo bar baz/],

Once a HashBase class is used as a subclass it is locked and no new fields can
be added. All constants from base classes are added to subclasses
automatically.

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

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

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
