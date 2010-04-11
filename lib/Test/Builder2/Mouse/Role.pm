package Mouse::Role;
use Mouse::Exporter; # enables strict and warnings

our $VERSION = '0.53';

use Carp         qw(confess);
use Scalar::Util qw(blessed);

use Mouse::Util  qw(not_supported);
use Mouse::Meta::Role;
use Mouse ();

Mouse::Exporter->setup_import_methods(
    as_is => [qw(
        extends with
        has
        before after around
        override super
        augment  inner

        requires excludes
    ),
        \&Scalar::Util::blessed,
        \&Carp::confess,
    ],
);


sub extends  {
    Carp::croak "Roles do not support 'extends'";
}

sub with     {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    Mouse::Util::apply_all_roles($meta->name, @_);
    return;
}

sub has {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
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
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_before_method_modifier($name => $code);
    }
    return;
}

sub after {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_after_method_modifier($name => $code);
    }
    return;
}

sub around {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    my $code = pop;
    for my $name($meta->_collect_methods(@_)) {
        $meta->add_around_method_modifier($name => $code);
    }
    return;
}


sub super {
    return if !defined $Mouse::SUPER_BODY;
    $Mouse::SUPER_BODY->(@Mouse::SUPER_ARGS);
}

sub override {
    # my($name, $code) = @_;
    Mouse::Meta::Role->initialize(scalar caller)->add_override_method_modifier(@_);
    return;
}

# We keep the same errors messages as Moose::Role emits, here.
sub inner {
    Carp::croak "Roles cannot support 'inner'";
}

sub augment {
    Carp::croak "Roles cannot support 'augment'";
}

sub requires {
    my $meta = Mouse::Meta::Role->initialize(scalar caller);
    $meta->throw_error("Must specify at least one method") unless @_;
    $meta->add_required_methods(@_);
    return;
}

sub excludes {
    not_supported;
}

sub init_meta{
    shift;
    my %args = @_;

    my $class = $args{for_class}
        or Carp::confess("Cannot call init_meta without specifying a for_class");

    my $metaclass  = $args{metaclass}  || 'Mouse::Meta::Role';

    my $meta = $metaclass->initialize($class);

    $meta->add_method(meta => sub{
        $metaclass->initialize(ref($_[0]) || $_[0]);
    });

    # make a role type for each Mouse role
    Mouse::Util::TypeConstraints::role_type($class)
        unless Mouse::Util::TypeConstraints::find_type_constraint($class);

    return $meta;
}

1;

__END__

=head1 NAME

Mouse::Role - The Mouse Role

=head1 VERSION

This document describes Mouse version 0.53

=head1 SYNOPSIS

    package MyRole;
    use Mouse::Role;

=head1 KEYWORDS

=head2 C<< meta -> Mouse::Meta::Role >>

Returns this role's metaclass instance.

=head2 C<< before (method|methods|regexp) -> CodeRef >>

Sets up a B<before> method modifier. See L<Moose/before>.

=head2 C<< after (method|methods|regexp) => CodeRef >>

Sets up an B<after> method modifier. See L<Moose/after>.

=head2 C<< around (method|methods|regexp) => CodeRef >>

Sets up an B<around> method modifier. See L<Moose/around>.

=head2 C<super>

Sets up the B<super> keyword. See L<Moose/super>.

=head2  C<< override method => CodeRef >>

Sets up an B<override> method modifier. See L<Moose/Role/override>.

=head2 C<inner>

This is not supported in roles and emits an error. See L<Moose/Role>.

=head2 C<< augment method => CodeRef >>

This is not supported in roles and emits an error. See L<Moose/Role>.

=head2 C<< has (name|names) => parameters >>

Sets up an attribute (or if passed an arrayref of names, multiple attributes) to
this role. See L<Mouse/has>.

=head2 C<< confess(error) -> BOOM >>

L<Carp/confess> for your convenience.

=head2 C<< blessed(value) -> ClassName | undef >>

L<Scalar::Util/blessed> for your convenience.

=head1 MISC

=head2 import

Importing Mouse::Role will give you sugar.

=head2 unimport

Please unimport (C<< no Mouse::Role >>) so that if someone calls one of the
keywords (such as L</has>) it will break loudly instead breaking subtly.

=head1 SEE ALSO

L<Moose::Role>

=cut

