package Test::Builder2::Mouse::Meta::TypeConstraint;
use Test::Builder2::Mouse::Util qw(:meta); # enables strict and warnings

use overload
    'bool'   => sub (){ 1 },           # always true
    '""'     => sub { $_[0]->name },   # stringify to tc name
    '|'      => sub {                  # or-combination
        require Test::Builder2::Mouse::Util::TypeConstraints;
        return Test::Builder2::Mouse::Util::TypeConstraints::find_or_parse_type_constraint(
            "$_[0] | $_[1]",
        );
    },

    fallback => 1;

sub new {
    my($class, %args) = @_;

    $args{name} = '__ANON__' if !defined $args{name};

    my $check = delete $args{optimized};

    if($check){
        $args{hand_optimized_type_constraint} = $check;
        $args{compiled_type_constraint}       = $check;
    }

    $check = $args{constraint};

    if(defined($check) && ref($check) ne 'CODE'){
        $class->throw_error("Constraint for $args{name} is not a CODE reference");
    }

    my $self = bless \%args, $class;
    $self->compile_type_constraint() if !$self->{hand_optimized_type_constraint};

    $self->_compile_union_type_coercion() if $self->{type_constraints};
    return $self;
}

sub create_child_type{
    my $self = shift;
    return ref($self)->new(
        # a child inherits its parent's attributes
        %{$self},

        # but does not inherit 'compiled_type_constraint' and 'hand_optimized_type_constraint'
        compiled_type_constraint       => undef,
        hand_optimized_type_constraint => undef,

        # and is given child-specific args, of course.
        @_,

        # and its parent
        parent => $self,
   );
}

sub name;
sub parent;
sub message;
sub has_coercion;

sub check;

sub type_parameter;
sub __is_parameterized;

sub _compiled_type_constraint;
sub _compiled_type_coercion;

sub compile_type_constraint;


sub _add_type_coercions{
    my $self = shift;

    my $coercions = ($self->{coercion_map} ||= []);
    my %has       = map{ $_->[0] => undef } @{$coercions};

    for(my $i = 0; $i < @_; $i++){
        my $from   = $_[  $i];
        my $action = $_[++$i];

        if(exists $has{$from}){
            $self->throw_error("A coercion action already exists for '$from'");
        }

        my $type = Test::Builder2::Mouse::Util::TypeConstraints::find_or_parse_type_constraint($from)
            or $self->throw_error("Could not find the type constraint ($from) to coerce from");

        push @{$coercions}, [ $type => $action ];
    }

    # compile
    if(exists $self->{type_constraints}){ # union type
        $self->throw_error("Cannot add additional type coercions to Union types");
    }
    else{
        $self->_compile_type_coercion();
    }
    return;
}

sub _compile_type_coercion {
    my($self) = @_;

    my @coercions = @{$self->{coercion_map}};

    $self->{_compiled_type_coercion} = sub {
       my($thing) = @_;
       foreach my $pair (@coercions) {
            #my ($constraint, $converter) = @$pair;
            if ($pair->[0]->check($thing)) {
              local $_ = $thing;
              return $pair->[1]->($thing);
            }
       }
       return $thing;
    };
    return;
}

sub _compile_union_type_coercion {
    my($self) = @_;

    my @coercions;
    foreach my $type(@{$self->{type_constraints}}){
        if($type->has_coercion){
            push @coercions, $type;
        }
    }
    if(@coercions){
        $self->{_compiled_type_coercion} = sub {
            my($thing) = @_;
            foreach my $type(@coercions){
                my $value = $type->coerce($thing);
                return $value if $self->check($value);
            }
            return $thing;
        };
    }
    return;
}

sub coerce {
    my $self = shift;

    my $coercion = $self->_compiled_type_coercion;
    if(!$coercion){
        $self->throw_error("Cannot coerce without a type coercion");
    }

    return $_[0] if $self->check(@_);

    return  $coercion->(@_);
}

sub get_message {
    my ($self, $value) = @_;
    if ( my $msg = $self->message ) {
        local $_ = $value;
        return $msg->($value);
    }
    else {
        $value = ( defined $value ? overload::StrVal($value) : 'undef' );
        return "Validation failed for '$self' failed with value $value";
    }
}

sub is_a_type_of{
    my($self, $other) = @_;

    # ->is_a_type_of('__ANON__') is always false
    return 0 if !ref($other) && $other eq '__ANON__';

    (my $other_name = $other) =~ s/\s+//g;

    return 1 if $self->name eq $other_name;

    if(exists $self->{type_constraints}){ # union
        foreach my $type(@{$self->{type_constraints}}){
            return 1 if $type->name eq $other_name;
        }
    }

    for(my $parent = $self->parent; defined $parent; $parent = $parent->parent){
        return 1 if $parent->name eq $other_name;
    }

    return 0;
}

# See also Moose::Meta::TypeConstraint::Parameterizable
sub parameterize{
    my($self, $param, $name) = @_;

    if(!ref $param){
        require Test::Builder2::Mouse::Util::TypeConstraints;
        $param = Test::Builder2::Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($param);
    }

    $name ||= sprintf '%s[%s]', $self->name, $param->name;

    my $generator = $self->{constraint_generator}
        || $self->throw_error("The $name constraint cannot be used, because $param doesn't subtype from a parameterizable type");

    return Test::Builder2::Mouse::Meta::TypeConstraint->new(
        name           => $name,
        parent         => $self,
        type_parameter => $param,
        constraint     => $generator->($param), # must be 'constraint', not 'optimized'
    );
}

sub assert_valid {
    my ($self, $value) = @_;

    if(!$self->check($value)){
        $self->throw_error($self->get_message($value));
    }
    return 1;
}

sub throw_error {
    require Test::Builder2::Mouse::Meta::Module;
    goto &Test::Builder2::Mouse::Meta::Module::throw_error;
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::TypeConstraint - The Mouse Type Constraint metaclass

=head1 VERSION

This document describes Mouse version 0.53

=head1 DESCRIPTION

For the most part, the only time you will ever encounter an
instance of this class is if you are doing some serious deep
introspection. This API should not be considered final, but
it is B<highly unlikely> that this will matter to a regular
Mouse user.

Don't use this.

=head1 METHODS

=over 4

=item B<new>

=item B<name>

=back

=head1 SEE ALSO

L<Moose::Meta::TypeConstraint>

=cut

