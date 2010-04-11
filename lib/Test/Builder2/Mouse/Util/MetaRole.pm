package Mouse::Util::MetaRole;
use Mouse::Util; # enables strict and warnings
use Scalar::Util ();

sub apply_metaclass_roles {
    my %args = @_;
    _fixup_old_style_args(\%args);

    return apply_metaroles(%args);
}

sub apply_metaroles {
    my %args = @_;

    my $for = Scalar::Util::blessed($args{for})
        ?                                     $args{for}
        : Mouse::Util::get_metaclass_by_name( $args{for} );

    if(!$for){
        Carp::confess("You must pass an initialized class, but '$args{for}' has no metaclass");
    }

    if ( Mouse::Util::is_a_metarole($for) ) {
        return _make_new_metaclass( $for, $args{role_metaroles}, 'role' );
    }
    else {
        return _make_new_metaclass( $for, $args{class_metaroles}, 'class' );
    }
}

sub _make_new_metaclass {
    my($for, $roles, $primary) = @_;

    return $for unless keys %{$roles};

    my $new_metaclass = exists($roles->{$primary})
        ? _make_new_class( ref $for, $roles->{$primary} ) # new class with traits
        :                  ref $for;

    my %classes;

    for my $key ( grep { $_ ne $primary } keys %{$roles} ) {
        my $metaclass;
        my $attr = $for->can($metaclass = ($key . '_metaclass'))
                || $for->can($metaclass = ($key . '_class'))
                || $for->throw_error("Unknown metaclass '$key'");

        $classes{ $metaclass }
            = _make_new_class( $for->$attr(), $roles->{$key} );
    }

    return $new_metaclass->reinitialize( $for, %classes );
}


sub _fixup_old_style_args {
    my $args = shift;

    return if $args->{class_metaroles} || $args->{roles_metaroles};

    $args->{for} = delete $args->{for_class}
        if exists $args->{for_class};

    my @old_keys = qw(
        attribute_metaclass_roles
        method_metaclass_roles
        wrapped_method_metaclass_roles
        instance_metaclass_roles
        constructor_class_roles
        destructor_class_roles
        error_class_roles

        application_to_class_class_roles
        application_to_role_class_roles
        application_to_instance_class_roles
        application_role_summation_class_roles
    );

    my $for = Scalar::Util::blessed($args->{for})
        ?                                     $args->{for}
        : Mouse::Util::get_metaclass_by_name( $args->{for} );

    my $top_key;
    if( Mouse::Util::is_a_metaclass($for) ){
        $top_key = 'class_metaroles';

        $args->{class_metaroles}{class} = delete $args->{metaclass_roles}
            if exists $args->{metaclass_roles};
    }
    else {
        $top_key = 'role_metaroles';

        $args->{role_metaroles}{role} = delete $args->{metaclass_roles}
            if exists $args->{metaclass_roles};
    }

    for my $old_key (@old_keys) {
        my ($new_key) = $old_key =~ /^(.+)_(?:class|metaclass)_roles$/;

        $args->{$top_key}{$new_key} = delete $args->{$old_key}
            if exists $args->{$old_key};
    }

    return;
}


sub apply_base_class_roles {
    my %options = @_;

    my $for = $options{for_class};

    my $meta = Mouse::Util::class_of($for);

    my $new_base = _make_new_class(
        $for,
        $options{roles},
        [ $meta->superclasses() ],
    );

    $meta->superclasses($new_base)
        if $new_base ne $meta->name();
    return;
}

sub _make_new_class {
    my($existing_class, $roles, $superclasses) = @_;

    if(!$superclasses){
        return $existing_class if !$roles;

        my $meta = Mouse::Meta::Class->initialize($existing_class);

        return $existing_class
            if !grep { !ref($_) && !$meta->does_role($_) } @{$roles};
    }

    return Mouse::Meta::Class->create_anon_class(
        superclasses => $superclasses ? $superclasses : [$existing_class],
        roles        => $roles,
        cache        => 1,
    )->name();
}

1;
__END__

=head1 NAME

Mouse::Util::MetaRole - Apply roles to any metaclass, as well as the object base class

=head1 SYNOPSIS

  package MyApp::Mouse;

  use Mouse ();
  use Mouse::Exporter;
  use Mouse::Util::MetaRole;

  use MyApp::Role::Meta::Class;
  use MyApp::Role::Meta::Method::Constructor;
  use MyApp::Role::Object;

  Mouse::Exporter->setup_import_methods( also => 'Mouse' );

  sub init_meta {
      shift;
      my %args = @_;

      Mouse->init_meta(%args);

      Mouse::Util::MetaRole::apply_metaroles(
          for             => $args{for_class},
          class_metaroles => {
              class       => ['MyApp::Role::Meta::Class'],
              constructor => ['MyApp::Role::Meta::Method::Constructor'],
          },
      );

      Mouse::Util::MetaRole::apply_base_class_roles(
          for   => $args{for_class},
          roles => ['MyApp::Role::Object'],
      );

      return $args{for_class}->meta();
  }

=head1 DESCRIPTION

This utility module is designed to help authors of Mouse extensions
write extensions that are able to cooperate with other Mouse
extensions. To do this, you must write your extensions as roles, which
can then be dynamically applied to the caller's metaclasses.

This module makes sure to preserve any existing superclasses and roles
already set for the meta objects, which means that any number of
extensions can apply roles in any order.

=head1 USAGE

B<It is very important that you only call this module's functions when
your module is imported by the caller>. The process of applying roles
to the metaclass reinitializes the metaclass object, which wipes out
any existing attributes already defined. However, as long as you do
this when your module is imported, the caller should not have any
attributes defined yet.

The easiest way to ensure that this happens is to use
L<Mouse::Exporter>, which can generate the appropriate C<init_meta>
method for you, and make sure it is called when imported.

=head1 FUNCTIONS

This module provides two functions.

=head2 apply_metaroles( ... )

This function will apply roles to one or more metaclasses for the
specified class. It accepts the following parameters:

=over 4

=item * for => $name

This specifies the class or for which to alter the meta classes. This can be a
package name, or an appropriate meta-object (a L<Mouse::Meta::Class> or
L<Mouse::Meta::Role>).

=item * class_metaroles => \%roles

This is a hash reference specifying which metaroles will be applied to the
class metaclass and its contained metaclasses and helper classes.

Each key should in turn point to an array reference of role names.

It accepts the following keys:

=over 8

=item class

=item attribute

=item method

=item constructor

=item destructor

=back

=item * role_metaroles => \%roles

This is a hash reference specifying which metaroles will be applied to the
role metaclass and its contained metaclasses and helper classes.

It accepts the following keys:

=over 8

=item role

=item method

=back

=back

=head2 apply_base_class_roles( for => $class, roles => \@roles )

This function will apply the specified roles to the object's base class.

=head1 SEE ALSO

L<Moose::Util::MetaRole>

=cut
