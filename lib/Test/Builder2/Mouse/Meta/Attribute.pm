package Test::Builder2::Mouse::Meta::Attribute;
use Test::Builder2::Mouse::Util qw(:meta); # enables strict and warnings

use Carp ();

use Test::Builder2::Mouse::Meta::TypeConstraint;

my %valid_options = map { $_ => undef } (
  'accessor',
  'auto_deref',
  'builder',
  'clearer',
  'coerce',
  'default',
  'documentation',
  'does',
  'handles',
  'init_arg',
  'is',
  'isa',
  'lazy',
  'lazy_build',
  'name',
  'predicate',
  'reader',
  'required',
  'traits',
  'trigger',
  'type_constraint',
  'weak_ref',
  'writer',

  # internally used
  'associated_class',
  'associated_methods',

  # Moose defines, but Mouse doesn't
  #'definition_context',
  #'initializer',
  #'insertion_order',

  # special case for AttributeHelpers
  'provides',
  'curries',
);

our @CARP_NOT = qw(Test::Builder2::Mouse::Meta::Class);

sub new {
    my $class = shift;
    my $name  = shift;

    my $args  = $class->Test::Builder2::Mouse::Object::BUILDARGS(@_);

    # XXX: for backward compatibility (with method modifiers)
    if($class->can('canonicalize_args') != \&canonicalize_args){
        %{$args} = $class->canonicalize_args($name, %{$args});
    }

    $class->_process_options($name, $args);

    $args->{name} = $name;

    # check options
    # (1) known by core
    my @bad = grep{ !exists $valid_options{$_} } keys %{$args};

    # (2) known by subclasses
    if(@bad && $class ne __PACKAGE__){
        my %valid_attrs = (
            map { $_ => undef }
            grep { defined }
            map { $_->init_arg() }
            $class->meta->get_all_attributes()
        );
        @bad = grep{ !exists $valid_attrs{$_} } @bad;
    }

    # (3) bad options found
    if(@bad){
        Carp::carp(
            "Found unknown argument(s) passed to '$name' attribute constructor in '$class': "
            . Test::Builder2::Mouse::Util::english_list(@bad));
    }

    my $self = bless $args, $class;

    # extra attributes
    if($class ne __PACKAGE__){
        $class->meta->_initialize_object($self, $args);
    }

    return $self;
}

sub has_read_method      { $_[0]->has_reader || $_[0]->has_accessor }
sub has_write_method     { $_[0]->has_writer || $_[0]->has_accessor }

sub _create_args { # DEPRECATED
    $_[0]->{_create_args} = $_[1] if @_ > 1;
    $_[0]->{_create_args}
}

sub interpolate_class{
    my($class, $args) = @_;

    if(my $metaclass = delete $args->{metaclass}){
        $class = Test::Builder2::Mouse::Util::resolve_metaclass_alias( Attribute => $metaclass );
    }

    my @traits;
    if(my $traits_ref = delete $args->{traits}){

        for (my $i = 0; $i < @{$traits_ref}; $i++) {
            my $trait = Test::Builder2::Mouse::Util::resolve_metaclass_alias(Attribute => $traits_ref->[$i], trait => 1);

            next if $class->does($trait);

            push @traits, $trait;

            # are there options?
            push @traits, $traits_ref->[++$i]
                if ref($traits_ref->[$i+1]);
        }

        if (@traits) {
            $class = Test::Builder2::Mouse::Meta::Class->create_anon_class(
                superclasses => [ $class ],
                roles        => \@traits,
                cache        => 1,
            )->name;
        }
    }

    return( $class, @traits );
}

sub canonicalize_args{ # DEPRECATED
    #my($self, $name, %args) = @_;
    my($self, undef, %args) = @_;

    Carp::cluck("$self->canonicalize_args has been deprecated."
        . "Use \$self->_process_options instead.");

    return %args;
}

sub create { # DEPRECATED
    #my($self, $class, $name, %args) = @_;
    my($self) = @_;

    Carp::cluck("$self->create has been deprecated."
        . "Use \$meta->add_attribute and \$attr->install_accessors instead.");

    # noop
    return $self;
}

sub _coerce_and_verify {
    #my($self, $value, $instance) = @_;
    my($self, $value) = @_;

    my $type_constraint = $self->{type_constraint};
    return $value if !defined $type_constraint;

    if ($self->should_coerce && $type_constraint->has_coercion) {
        $value = $type_constraint->coerce($value);
    }

    $self->verify_against_type_constraint($value);

    return $value;
}

sub verify_against_type_constraint {
    my ($self, $value) = @_;

    my $type_constraint = $self->{type_constraint};
    return 1 if !$type_constraint;
    return 1 if $type_constraint->check($value);

    $self->_throw_type_constraint_error($value, $type_constraint);
}

sub _throw_type_constraint_error {
    my($self, $value, $type) = @_;

    $self->throw_error(
        sprintf q{Attribute (%s) does not pass the type constraint because: %s},
            $self->name,
            $type->get_message($value),
    );
}

sub clone_and_inherit_options{
    my $self = shift;
    my $args = $self->Test::Builder2::Mouse::Object::BUILDARGS(@_);

    my($attribute_class, @traits) = ref($self)->interpolate_class($args);

    $args->{traits} = \@traits if @traits;
    # do not inherit the 'handles' attribute
    foreach my $name(keys %{$self}){
        if(!exists $args->{$name} && $name ne 'handles'){
            $args->{$name} = $self->{$name};
        }
    }

    # remove temporary caches
    foreach my $attr(keys %{$args}){
        if($attr =~ /\A _/xms){
            delete $args->{$attr};
        }
    }

    return $attribute_class->new($self->name, $args);
}

sub clone_parent { # DEPRECATED
    my $self  = shift;
    my $class = shift;
    my $name  = shift;
    my %args  = ($self->get_parent_args($class, $name), @_);

    Carp::cluck("$self->clone_parent has been deprecated."
        . "Use \$meta->add_attribute and \$attr->install_accessors instead.");

    $self->clone_and_inherited_args($class, $name, %args);
}

sub get_parent_args { # DEPRECATED
    my $self  = shift;
    my $class = shift;
    my $name  = shift;

    for my $super ($class->linearized_isa) {
        my $super_attr = $super->can("meta") && $super->meta->get_attribute($name)
            or next;
        return %{ $super_attr->_create_args };
    }

    $self->throw_error("Could not find an attribute by the name of '$name' to inherit from");
}


sub get_read_method {
    return $_[0]->reader || $_[0]->accessor
}
sub get_write_method {
    return $_[0]->writer || $_[0]->accessor
}

sub _get_accessor_method_ref {
    my($self, $type, $generator) = @_;

    my $metaclass = $self->associated_class
        || $self->throw_error('No asocciated class for ' . $self->name);

    my $accessor = $self->$type();
    if($accessor){
        return $metaclass->get_method_body($accessor);
    }
    else{
        return $self->accessor_metaclass->$generator($self, $metaclass);
    }
}

sub get_read_method_ref{
    my($self) = @_;
    return $self->{_read_method_ref} ||= $self->_get_accessor_method_ref('get_read_method', '_generate_reader');
}

sub get_write_method_ref{
    my($self) = @_;
    return $self->{_write_method_ref} ||= $self->_get_accessor_method_ref('get_write_method', '_generate_writer');
}

sub set_value {
    my($self, $object, $value) = @_;
    return $self->get_write_method_ref()->($object, $value);
}

sub get_value {
    my($self, $object) = @_;
    return $self->get_read_method_ref()->($object);
}

sub has_value {
    my($self, $object) = @_;
    my $accessor_ref = $self->{_predicate_ref}
        ||= $self->_get_accessor_method_ref('predicate', '_generate_predicate');

    return $accessor_ref->($object);
}

sub clear_value {
    my($self, $object) = @_;
    my $accessor_ref = $self->{_crealer_ref}
        ||= $self->_get_accessor_method_ref('clearer', '_generate_clearer');

    return $accessor_ref->($object);
}


sub associate_method{
    #my($attribute, $method_name) = @_;
    my($attribute) = @_;
    $attribute->{associated_methods}++;
    return;
}

sub install_accessors{
    my($attribute) = @_;

    my $metaclass      = $attribute->associated_class;
    my $accessor_class = $attribute->accessor_metaclass;

    foreach my $type(qw(accessor reader writer predicate clearer)){
        if(exists $attribute->{$type}){
            my $generator = '_generate_' . $type;
            my $code      = $accessor_class->$generator($attribute, $metaclass);
            $metaclass->add_method($attribute->{$type} => $code);
            $attribute->associate_method($attribute->{$type});
        }
    }

    # install delegation
    if(exists $attribute->{handles}){
        my %handles = $attribute->_canonicalize_handles($attribute->{handles});

        while(my($handle, $method_to_call) = each %handles){
            $metaclass->add_method($handle =>
                $attribute->_make_delegation_method(
                    $handle, $method_to_call));

            $attribute->associate_method($handle);
        }
    }

    if($attribute->can('create') != \&create){
        # backword compatibility
        $attribute->create($metaclass, $attribute->name, %{$attribute});
    }

    return;
}

sub delegation_metaclass() { ## no critic
    'Test::Builder2::Mouse::Meta::Method::Delegation'
}

sub _canonicalize_handles {
    my($self, $handles) = @_;

    if (ref($handles) eq 'HASH') {
        return %$handles;
    }
    elsif (ref($handles) eq 'ARRAY') {
        return map { $_ => $_ } @$handles;
    }
    elsif ( ref($handles) eq 'CODE' ) {
        my $class_or_role = ( $self->{isa} || $self->{does} )
            || $self->throw_error( "Cannot find delegate metaclass for attribute " . $self->name );
        return $handles->( $self, Test::Builder2::Mouse::Meta::Class->initialize("$class_or_role"));
    }
    elsif (ref($handles) eq 'Regexp') {
        my $class_or_role = ($self->{isa} || $self->{does})
            || $self->throw_error("Cannot delegate methods based on a Regexp without a type constraint (isa)");

        my $meta = Test::Builder2::Mouse::Meta::Class->initialize("$class_or_role"); # "" for stringify
        return map  { $_ => $_ }
               grep { !Test::Builder2::Mouse::Object->can($_) && $_ =~ $handles }
                   Test::Builder2::Mouse::Util::is_a_metarole($meta)
                        ? $meta->get_method_list
                        : $meta->get_all_method_names;
    }
    else {
        $self->throw_error("Unable to canonicalize the 'handles' option with $handles");
    }
}

sub _make_delegation_method {
    my($self, $handle, $method_to_call) = @_;
    return Test::Builder2::Mouse::Util::load_class($self->delegation_metaclass)
        ->_generate_delegation($self, $handle, $method_to_call);
}

sub throw_error{
    my $self = shift;

    my $metaclass = (ref $self && $self->associated_class) || 'Test::Builder2::Mouse::Meta::Class';
    $metaclass->throw_error(@_, depth => 1);
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Attribute - The Mouse attribute metaclass

=head1 VERSION

This document describes Mouse version 0.53

=head1 METHODS

=head2 C<< new(%options) -> Test::Builder2::Mouse::Meta::Attribute >>

Instantiates a new Test::Builder2::Mouse::Meta::Attribute. Does nothing else.

It adds the following options to the constructor:

=over 4

=item C<< is => 'ro', 'rw', 'bare' >>

This provides a shorthand for specifying the C<reader>, C<writer>, or
C<accessor> names. If the attribute is read-only ('ro') then it will
have a C<reader> method with the same attribute as the name.

If it is read-write ('rw') then it will have an C<accessor> method
with the same name. If you provide an explicit C<writer> for a
read-write attribute, then you will have a C<reader> with the same
name as the attribute, and a C<writer> with the name you provided.

Use 'bare' when you are deliberately not installing any methods
(accessor, reader, etc.) associated with this attribute; otherwise,
Moose will issue a deprecation warning when this attribute is added to a
metaclass.

=item C<< isa => Type >>

This option accepts a type. The type can be a string, which should be
a type name. If the type name is unknown, it is assumed to be a class
name.

This option can also accept a L<Moose::Meta::TypeConstraint> object.

If you I<also> provide a C<does> option, then your C<isa> option must
be a class name, and that class must do the role specified with
C<does>.

=item C<< does => Role >>

This is short-hand for saying that the attribute's type must be an
object which does the named role.

B<This option is not yet supported.>

=item C<< coerce => Bool >>

This option is only valid for objects with a type constraint
(C<isa>). If this is true, then coercions will be applied whenever
this attribute is set.

You can make both this and the C<weak_ref> option true.

=item C<< trigger => CodeRef >>

This option accepts a subroutine reference, which will be called after
the attribute is set.

=item C<< required => Bool >>

An attribute which is required must be provided to the constructor. An
attribute which is required can also have a C<default> or C<builder>,
which will satisfy its required-ness.

A required attribute must have a C<default>, C<builder> or a
non-C<undef> C<init_arg>

=item C<< lazy => Bool >>

A lazy attribute must have a C<default> or C<builder>. When an
attribute is lazy, the default value will not be calculated until the
attribute is read.

=item C<< weak_ref => Bool >>

If this is true, the attribute's value will be stored as a weak
reference.

=item C<< auto_deref => Bool >>

If this is true, then the reader will dereference the value when it is
called. The attribute must have a type constraint which defines the
attribute as an array or hash reference.

=item C<< lazy_build => Bool >>

Setting this to true makes the attribute lazy and provides a number of
default methods.

  has 'size' => (
      is         => 'ro',
      lazy_build => 1,
  );

is equivalent to this:

  has 'size' => (
      is        => 'ro',
      lazy      => 1,
      builder   => '_build_size',
      clearer   => 'clear_size',
      predicate => 'has_size',
  );

=back

=head2 C<< associate_method(MethodName) >>

Associates a method with the attribute. Typically, this is called internally
when an attribute generates its accessors.

Currently the argument I<MethodName> is ignored in Mouse.

=head2 C<< verify_against_type_constraint(Item) -> TRUE | ERROR >>

Checks that the given value passes this attribute's type constraint. Returns C<true>
on success, otherwise C<confess>es.

=head2 C<< clone_and_inherit_options(options) -> Test::Builder2::Mouse::Meta::Attribute >>

Creates a new attribute in the owner class, inheriting options from parent classes.
Accessors and helper methods are installed. Some error checking is done.

=head2 C<< get_read_method_ref >>

=head2 C<< get_write_method_ref >>

Returns the subroutine reference of a method suitable for reading or
writing the attribute's value in the associated class. These methods
always return a subroutine reference, regardless of whether or not the
attribute is read- or write-only.

=head1 SEE ALSO

L<Moose::Meta::Attribute>

L<Class::MOP::Attribute>

=cut

