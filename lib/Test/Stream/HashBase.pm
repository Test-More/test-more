package Test::Stream::HashBase;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/blessed reftype/;

my (%META);

sub import {
    my ($class, %args) = @_;

    my $into = $args{into} || caller;
    my $meta = $META{$into} = $args{accessors} || [];

    my $eval = "package $into;\n";
    if(my $base = $args{base}) {
        my $bmeta = $META{$base} || croak "Base class '$base' is not a HashBase class";

        $eval .= "sub " . uc($_) . "() { '$_' };\n" for @$bmeta;

        no strict 'refs';
        push @{"$into\::ISA"} => $base
            unless $into->isa($base);
    }

    $eval .= join '' => map {
        my $const = uc($_);
        <<"        EOT"
sub $const() { '$_' }
sub $_       { \$_[0]->{'$_'} }
sub set_$_   { \$_[0]->{'$_'} = \$_[1] }
        EOT
    } @$meta;

    eval "${eval}1;" || die $@;

    no strict 'refs';
    *{"$into\::new"} = \&_new;
}

sub _new {
    my ($class, %params) = @_;
    my $self = bless \%params, $class;
    $self->init if $self->can('init');
    $self;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::HashBase - Base class for classes that use a hashref
of a hash.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

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
                          accessors => ['bat'];

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


    $one->{+FOO} = 'xxx';

=head1 DESCRIPTION

This package is used to generate classes based on hashrefs. Using this class
will give you a C<new()> method, as well as generating accessors you request.
Generated accessors will be getters, C<set_ACCESSOR> setters will also be
generated for you. You also get constants for each accessor (all caps) which
return the key into the hash for that accessor. Single inheritence is also
supported.

=head1 METHODS

=head2 PROVIDED BY HASH BASE

=over 4

=item $it = $class->new(@VALUES)

Create a new instance using key/value pairs.

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
        accessors => [qw/foo bar baz/];

The base class is added to C<@ISA> for you, and all constants from base classes
are added to subclasses automatically.

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
