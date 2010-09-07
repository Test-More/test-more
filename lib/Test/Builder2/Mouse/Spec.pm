package Test::Builder2::Mouse::Spec;
use strict;
use warnings;

our $VERSION = '0.64';

our $MouseVersion = $VERSION;
our $MooseVersion = '1.05';

sub MouseVersion{ $MouseVersion }
sub MooseVersion{ $MooseVersion }

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Spec - To what extent Mouse is compatible with Moose

=head1 VERSION

This document describes Mouse version 0.64

=head1 SYNOPSIS

    use Test::Builder2::Mouse::Spec;

    printf "Test/Builder2/Mouse/%s is compatible with Moose/%s\n",
        Test::Builder2::Mouse::Spec->MouseVersion, Test::Builder2::Mouse::Spec->MooseVersion;

=head1 DESCRIPTION

Mouse is a subset of Moose. This document describes to what extend Mouse is
compatible with Moose.

=head2 Compatibility with Moose

The sugary API is highly compatible with Moose.

=head2 Incompatibility with Moose

=head3 Meta object protocols

Any MOP in Mouse has no attributes by default.

For this reason, C<< $metaclass->meta->make_immutable() >> does not yet work as you expect.
B<Don not make metaclasses immutable>.

=head3 Test::Builder2::Mouse::Meta::Instance

Meta instance mechanism is not implemented.

=head3 Role exclusion

Role exclusion, C<exclude()>, is not implemented.

=head3 -metaclass in Test::Builder2::Mouse::Exporter

C<< use Test::Builder2::Mouse -metaclass => ... >> are not implemented.
Use C<< use Test::Builder2::Mouse -traits => ... >> instead.

=head3 Test::Builder2::Mouse::Meta::Attribute::Native

Native traits are not supported directly, but C<MouseX::NativeTraits> is
available on CPAN. Once you have installed it, you can use it as the same way
in Moose. That is, native traits are automatically loaded by Mouse.

See L<MouseX::NativeTraits> for details.

=head2 Notes about Moose::Cookbook

Many recipes in L<Moose::Cookbook> fit L<Mouse>, including:

=over 4

=item *

L<Moose::Cookbook::Basics::Recipe1> - The (always classic) B<Point> example

=item *

L<Moose::Cookbook::Basics::Recipe2> - A simple B<BankAccount> example

=item *

L<Moose::Cookbook::Basics::Recipe3> - A lazy B<BinaryTree> example

=item *

L<Moose::Cookbook::Basics::Recipe4> - Subtypes, and modeling a simple B<Company> class hierarchy

=item *

L<Moose::Cookbook::Basics::Recipe5> - More subtypes, coercion in a B<Request> class

=item *

L<Moose::Cookbook::Basics::Recipe6> - The augment/inner example

=item *

L<Moose::Cookbook::Basics::Recipe7> - Making Moose fast with immutable

=item *

L<Moose::Cookbook::Basics::Recipe8> - Builder methods and lazy_build

=item *

L<Moose::Cookbook::Basics::Recipe9> - Operator overloading, subtypes, and coercion

=item *

L<Moose::Cookbook::Basics::Recipe10> - Using BUILDARGS and BUILD to hook into object construction

=item *

L<Moose::Cookbook::Roles::Recipe1> - The Moose::Role example

=item *

L<Moose::Cookbook::Roles::Recipe2> - Advanced Role Composition - method exclusion and aliasing

=item *

L<Moose::Cookbook::Roles::Recipe3> - Applying a role to an object instance

=item *

L<Moose::Cookbook::Meta::Recipe2> - A meta-attribute, attributes with labels

=item *

L<Moose::Cookbook::Meta::Recipe3> - Labels implemented via attribute traits

=item *

L<Moose::Cookbook::Extending::Recipe3> - Providing an alternate base object class

=back

=head1 SEE ALSO

L<Mouse>

L<Moose>

L<Moose::Manual>

L<Moose::Cookbook>

=cut

