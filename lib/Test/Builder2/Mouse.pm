package Test::Builder2::Mouse;
use 5.006_002;

use Test::Builder2::Mouse::Exporter; # enables strict and warnings

our $VERSION = '0.64';

use Carp         qw(confess);
use Scalar::Util qw(blessed);

use Test::Builder2::Mouse::Util ();

use Test::Builder2::Mouse::Meta::Module;
use Test::Builder2::Mouse::Meta::Class;
use Test::Builder2::Mouse::Meta::Role;
use Test::Builder2::Mouse::Meta::Attribute;
use Test::Builder2::Mouse::Object;
use Test::Builder2::Mouse::Util::TypeConstraints ();

Test::Builder2::Mouse::Exporter->setup_import_methods(
    as_is => [qw(
        extends with
        has
        before after around
        override super
        augment  inner
    ),
        \&Scalar::Util::blessed,
        \&Carp::confess,
   ],
);


sub extends {
    Test::Builder2::Mouse::Meta::Class->initialize(scalar caller)->superclasses(@_);
    return;
}

sub with {
    Test::Builder2::Mouse::Util::apply_all_roles(scalar(caller), @_);
    return;
}

sub has {
    my $meta = Test::Builder2::Mouse::Meta::Class->initialize(scalar caller);
    my $name = shift;

    $meta->throw_error(q{Usage: has 'name' => ( key => value, ... )})
        if @_ % 2; # odd number of arguments

    if(ref $name){ # has [qw(foo bar)] => (...)
        for (@{$name}){
            $meta->add_attribute($_ => @_);
        }
    }
    else{ # has foo => (...)
        $meta->add_attribute($name => @_);
    }
    return;
}

sub before {
    my $meta = Test::Builder2::Mouse::Meta::Class->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_before_method_modifier($name => $code);
    }
    return;
}

sub after {
    my $meta = Test::Builder2::Mouse::Meta::Class->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_after_method_modifier($name => $code);
    }
    return;
}

sub around {
    my $meta = Test::Builder2::Mouse::Meta::Class->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_around_method_modifier($name => $code);
    }
    return;
}

our $SUPER_PACKAGE;
our $SUPER_BODY;
our @SUPER_ARGS;

sub super {
    # This check avoids a recursion loop - see
    # t/100_bugs/020_super_recursion.t
    return if  defined $SUPER_PACKAGE && $SUPER_PACKAGE ne caller();
    return if !defined $SUPER_BODY;
    $SUPER_BODY->(@SUPER_ARGS);
}

sub override {
    # my($name, $method) = @_;
    Test::Builder2::Mouse::Meta::Class->initialize(scalar caller)->add_override_method_modifier(@_);
}

our %INNER_BODY;
our %INNER_ARGS;

sub inner {
    my $pkg = caller();
    if ( my $body = $INNER_BODY{$pkg} ) {
        my $args = $INNER_ARGS{$pkg};
        local $INNER_ARGS{$pkg};
        local $INNER_BODY{$pkg};
        return $body->(@{$args});
    }
    else {
        return;
    }
}

sub augment {
    #my($name, $method) = @_;
    Test::Builder2::Mouse::Meta::Class->initialize(scalar caller)->add_augment_method_modifier(@_);
    return;
}

sub init_meta {
    shift;
    my %args = @_;

    my $class = $args{for_class}
                    or confess("Cannot call init_meta without specifying a for_class");

    my $base_class = $args{base_class} || 'Test::Builder2::Mouse::Object';
    my $metaclass  = $args{metaclass}  || 'Test::Builder2::Mouse::Meta::Class';

    my $meta = $metaclass->initialize($class);

    $meta->add_method(meta => sub{
        return $metaclass->initialize(ref($_[0]) || $_[0]);
    });

    $meta->superclasses($base_class)
        unless $meta->superclasses;

    # make a class type for each Mouse class
    Test::Builder2::Mouse::Util::TypeConstraints::class_type($class)
        unless Test::Builder2::Mouse::Util::TypeConstraints::find_type_constraint($class);

    return $meta;
}

1;
__END__

=head1 NAME

Mouse - Moose minus the antlers

=head1 VERSION

This document describes Mouse version 0.64

=head1 SYNOPSIS

    package Point;
    use Mouse; # automatically turns on strict and warnings

    has 'x' => (is => 'rw', isa => 'Int');
    has 'y' => (is => 'rw', isa => 'Int');

    sub clear {
        my $self = shift;
        $self->x(0);
        $self->y(0);
    }


    __PACKAGE__->meta->make_immutable();

    package Point3D;
    use Mouse;

    extends 'Point';

    has 'z' => (is => 'rw', isa => 'Int');

    after 'clear' => sub {
        my $self = shift;
        $self->z(0);
    };

    __PACKAGE__->meta->make_immutable();

=head1 DESCRIPTION

L<Moose> is wonderful. B<Use Moose instead of Mouse.>

Unfortunately, Moose has a compile-time penalty. Though significant progress
has been made over the years, the compile time penalty is a non-starter for
some very specific applications. If you are writing a command-line application
or CGI script where startup time is essential, you may not be able to use
Moose. We recommend that you instead use L<HTTP::Engine> and FastCGI for the
latter, if possible.

Mouse aims to alleviate this by providing a subset of Moose's functionality,
faster.

We're also going as light on dependencies as possible. Mouse currently has
B<no dependencies> except for testing modules.

=head2 MOOSE COMPATIBILITY

Compatibility with Moose has been the utmost concern. The sugary interface is
highly compatible with Moose. Even the error messages are taken from Moose.
The Mouse code just runs the test suite 4x faster.

The idea is that, if you need the extra power, you should be able to run
C<s/Test/Builder2/Mouse/Moose/g> on your codebase and have nothing break. To that end,
we have written L<Any::Moose> which will act as Mouse unless Moose is loaded,
in which case it will act as Moose. Since Mouse is a little sloppier than
Moose, if you run into weird errors, it would be worth running:

    ANY_MOOSE=Moose perl your-script.pl

to see if the bug is caused by Mouse. Moose's diagnostics and validation are
also better.

See also L<Test::Builder2::Mouse::Spec> for compatibility and incompatibility with Moose.

=head2 MouseX

Please don't copy MooseX code to MouseX. If you need extensions, you really
should upgrade to Moose. We don't need two parallel sets of extensions!

If you really must write a Mouse extension, please contact the Moose mailing
list or #moose on IRC beforehand.

=head1 KEYWORDS

=head2 C<< $object->meta -> Test::Builder2::Mouse::Meta::Class >>

Returns this class' metaclass instance.

=head2 C<< extends superclasses >>

Sets this class' superclasses.

=head2 C<< before (method|methods|regexp) => CodeRef >>

Installs a "before" method modifier. See L<Moose/before>.

=head2 C<< after (method|methods|regexp) => CodeRef >>

Installs an "after" method modifier. See L<Moose/after>.

=head2 C<< around (method|methods|regexp) => CodeRef >>

Installs an "around" method modifier. See L<Moose/around>.

=head2 C<< has (name|names) => parameters >>

Adds an attribute (or if passed an arrayref of names, multiple attributes) to
this class. Options:

=over 4

=item C<< is => ro|rw|bare >>

The I<is> option accepts either I<rw> (for read/write), I<ro> (for read
only) or I<bare> (for nothing). These will create either a read/write accessor
or a read-only accessor respectively, using the same name as the C<$name> of
the attribute.

If you need more control over how your accessors are named, you can
use the C<reader>, C<writer> and C<accessor> options, however if you
use those, you won't need the I<is> option.

=item C<< isa => TypeName | ClassName >>

Provides type checking in the constructor and accessor. The following types are
supported. Any unknown type is taken to be a class check
(e.g. C<< isa => 'DateTime' >> would accept only L<DateTime> objects).

    Any Item Bool Undef Defined Value Num Int Str ClassName
    Ref ScalarRef ArrayRef HashRef CodeRef RegexpRef GlobRef
    FileHandle Object

For more documentation on type constraints, see L<Test::Builder2::Mouse::Util::TypeConstraints>.

=item C<< does => RoleName >>

This will accept the name of a role which the value stored in this attribute
is expected to have consumed.

=item C<< coerce => Bool >>

This will attempt to use coercion with the supplied type constraint to change
the value passed into any accessors or constructors. You B<must> have supplied
a type constraint in order for this to work. See L<Moose::Cookbook::Basics::Recipe5>
for an example.

=item C<< required => Bool >>

Whether this attribute is required to have a value. If the attribute is lazy or
has a builder, then providing a value for the attribute in the constructor is
optional.

=item C<< init_arg => Str | Undef >>

Allows you to use a different key name in the constructor.  If undef, the
attribute can't be passed to the constructor.

=item C<< default => Value | CodeRef >>

Sets the default value of the attribute. If the default is a coderef, it will
be invoked to get the default value. Due to quirks of Perl, any bare reference
is forbidden, you must wrap the reference in a coderef. Otherwise, all
instances will share the same reference.

=item C<< lazy => Bool >>

If specified, the default is calculated on demand instead of in the
constructor.

=item C<< predicate => Str >>

Lets you specify a method name for installing a predicate method, which checks
that the attribute has a value. It will not invoke a lazy default or builder
method.

=item C<< clearer => Str >>

Lets you specify a method name for installing a clearer method, which clears
the attribute's value from the instance. On the next read, lazy or builder will
be invoked.

=item C<< handles => HashRef|ArrayRef|Regexp >>

Lets you specify methods to delegate to the attribute. ArrayRef forwards the
given method names to method calls on the attribute. HashRef maps local method
names to remote method names called on the attribute. Other forms of
L</handles>, such as RoleName and CodeRef, are not yet supported.

=item C<< weak_ref => Bool >>

Lets you automatically weaken any reference stored in the attribute.

Use of this feature requires L<Scalar::Util>!

=item C<< trigger => CodeRef >>

Any time the attribute's value is set (either through the accessor or the constructor), the trigger is called on it. The trigger receives as arguments the instance, the new value, and the attribute instance.

=item C<< builder => Str >>

Defines a method name to be called to provide the default value of the
attribute. C<< builder => 'build_foo' >> is mostly equivalent to
C<< default => sub { $_[0]->build_foo } >>.

=item C<< auto_deref => Bool >>

Allows you to automatically dereference ArrayRef and HashRef attributes in list
context. In scalar context, the reference is returned (NOT the list length or
bucket status). You must specify an appropriate type constraint to use
auto_deref.

=item C<< lazy_build => Bool >>

Automatically define the following options:

    has $attr => (
        # ...
        lazy      => 1
        builder   => "_build_$attr",
        clearer   => "clear_$attr",
        predicate => "has_$attr",
    );

=back

=head2 C<< confess(message) -> BOOM >>

L<Carp/confess> for your convenience.

=head2 C<< blessed(value) -> ClassName | undef >>

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse will default your class' superclass list to L<Test::Builder2::Mouse::Object>.
You may use L</extends> to replace the superclass list.

=head2 unimport

Please unimport Mouse (C<no Mouse>) so that if someone calls one of the
keywords (such as L</extends>) it will break loudly instead breaking subtly.

=head1 SOURCE CODE ACCESS

We have a public git repository:

 git clone git://git.moose.perl.org/Mouse.git

=head1 DEPENDENCIES

Perl 5.6.2 or later.

=head1 SEE ALSO

L<Test::Builder2::Mouse::Spec>

L<Moose>

L<Moose::Manual>

L<Moose::Cookbook>

L<Class::MOP>

=head1 AUTHORS

Shawn M Moore E<lt>sartak at gmail.comE<gt>

Yuval Kogman E<lt>nothingmuch at woobling.orgE<gt>

tokuhirom

Yappo

wu-lee

Goro Fuji (gfx) E<lt>gfuji at cpan.orgE<gt>

with plenty of code borrowed from L<Class::MOP> and L<Moose>

=head1 BUGS

All complex software has bugs lurking in it, and this module is no exception.
Please report any bugs to C<bug-mouse at rt.cpan.org>, or through the web
interface at L<http://rt.cpan.org/Public/Dist/Display.html?Name=Mouse>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008-2010 Infinity Interactive, Inc.

http://www.iinteractive.com/

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

