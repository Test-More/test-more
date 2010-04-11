package Test::Builder2::Mouse::PurePerl;

require Test::Builder2::Mouse::Util;

package Test::Builder2::Mouse::Util;

use strict;
use warnings;

use warnings FATAL => 'redefine'; # to avoid to load Test::Builder2::Mouse::PurePerl

use B ();


# taken from Class/MOP.pm
sub is_valid_class_name {
    my $class = shift;

    return 0 if ref($class);
    return 0 unless defined($class);

    return 1 if $class =~ /\A \w+ (?: :: \w+ )* \z/xms;

    return 0;
}

sub is_class_loaded {
    my $class = shift;

    return 0 if ref($class) || !defined($class) || !length($class);

    # walk the symbol table tree to avoid autovififying
    # \*{${main::}{"Foo::"}{"Bar::"}} == \*main::Foo::Bar::

    my $pack = \%::;
    foreach my $part (split('::', $class)) {
        $part .= '::';
        return 0 if !exists $pack->{$part};

        my $entry = \$pack->{$part};
        return 0 if ref($entry) ne 'GLOB';
        $pack = *{$entry}{HASH};
    }

    return 0 if !%{$pack};

    # check for $VERSION or @ISA
    return 1 if exists $pack->{VERSION}
             && defined *{$pack->{VERSION}}{SCALAR} && defined ${ $pack->{VERSION} };
    return 1 if exists $pack->{ISA}
             && defined *{$pack->{ISA}}{ARRAY} && @{ $pack->{ISA} } != 0;

    # check for any method
    foreach my $name( keys %{$pack} ) {
        my $entry = \$pack->{$name};
        return 1 if ref($entry) ne 'GLOB' || defined *{$entry}{CODE};
    }

    # fail
    return 0;
}


# taken from Sub::Identify
sub get_code_info {
    my ($coderef) = @_;
    ref($coderef) or return;

    my $cv = B::svref_2object($coderef);
    $cv->isa('B::CV') or return;

    my $gv = $cv->GV;
    $gv->isa('B::GV') or return;

    return ($gv->STASH->NAME, $gv->NAME);
}

sub get_code_package{
    my($coderef) = @_;

    my $cv = B::svref_2object($coderef);
    $cv->isa('B::CV') or return '';

    my $gv = $cv->GV;
    $gv->isa('B::GV') or return '';

    return $gv->STASH->NAME;
}

sub get_code_ref{
    my($package, $name) = @_;
    no strict 'refs';
    no warnings 'once';
    use warnings FATAL => 'uninitialized';
    return *{$package . '::' . $name}{CODE};
}

sub generate_isa_predicate_for {
    my($for_class, $name) = @_;

    my $predicate = sub{ Scalar::Util::blessed($_[0]) && $_[0]->isa($for_class) };

    if(defined $name){
        Test::Builder2::Mouse::Util::install_subroutines(scalar caller, $name => $predicate);
        return;
    }

    return $predicate;
}

sub generate_can_predicate_for {
    my($methods_ref, $name) = @_;

    my @methods = @{$methods_ref};

    my $predicate = sub{
        my($instance) = @_;
        if(Scalar::Util::blessed($instance)){
            foreach my $method(@methods){
                if(!$instance->can($method)){
                    return 0;
                }
            }
            return 1;
        }
        return 0;
    };

    if(defined $name){
        Test::Builder2::Mouse::Util::install_subroutines(scalar caller, $name => $predicate);
        return;
    }

    return $predicate;
}

package Test::Builder2::Mouse::Util::TypeConstraints;

use Scalar::Util qw(blessed looks_like_number openhandle);

sub Any        { 1 }
sub Item       { 1 }

sub Bool       { $_[0] ? $_[0] eq '1' : 1 }
sub Undef      { !defined($_[0]) }
sub Defined    {  defined($_[0])  }
sub Value      {  defined($_[0]) && !ref($_[0]) }
sub Num        {  looks_like_number($_[0]) }
sub Int        {
    my($value) = @_;
    looks_like_number($value) && $value =~ /\A [+-]? [0-9]+  \z/xms;
}
sub Str        {
    my($value) = @_;
    return defined($value) && ref(\$value) eq 'SCALAR';
}

sub Ref        { ref($_[0]) }
sub ScalarRef  {
    my($value) = @_;
    return ref($value) eq 'SCALAR'
}
sub ArrayRef   { ref($_[0]) eq 'ARRAY'  }
sub HashRef    { ref($_[0]) eq 'HASH'   }
sub CodeRef    { ref($_[0]) eq 'CODE'   }
sub RegexpRef  { ref($_[0]) eq 'Regexp' }
sub GlobRef    { ref($_[0]) eq 'GLOB'   }

sub FileHandle {
    return openhandle($_[0])  || (blessed($_[0]) && $_[0]->isa("IO::Handle"))
}

sub Object     { blessed($_[0]) && blessed($_[0]) ne 'Regexp' }

sub ClassName  { Test::Builder2::Mouse::Util::is_class_loaded($_[0]) }
sub RoleName   { (Test::Builder2::Mouse::Util::class_of($_[0]) || return 0)->isa('Mouse::Meta::Role') }

sub _parameterize_ArrayRef_for {
    my($type_parameter) = @_;
    my $check = $type_parameter->_compiled_type_constraint;

    return sub {
        foreach my $value (@{$_}) {
            return undef unless $check->($value);
        }
        return 1;
    }
}

sub _parameterize_HashRef_for {
    my($type_parameter) = @_;
    my $check = $type_parameter->_compiled_type_constraint;

    return sub {
        foreach my $value(values %{$_}){
            return undef unless $check->($value);
        }
        return 1;
    };
}

# 'Maybe' type accepts 'Any', so it requires parameters
sub _parameterize_Maybe_for {
    my($type_parameter) = @_;
    my $check = $type_parameter->_compiled_type_constraint;

    return sub{
        return !defined($_) || $check->($_);
    };
}

package Test::Builder2::Mouse::Meta::Module;

sub name          { $_[0]->{package} }

sub _method_map   { $_[0]->{methods} }
sub _attribute_map{ $_[0]->{attributes} }

sub namespace{
    my $name = $_[0]->{package};
    no strict 'refs';
    return \%{ $name . '::' };
}

sub add_method {
    my($self, $name, $code) = @_;

    if(!defined $name){
        $self->throw_error('You must pass a defined name');
    }
    if(!defined $code){
        $self->throw_error('You must pass a defined code');
    }

    if(ref($code) ne 'CODE'){
        $code = \&{$code}; # coerce
    }

    $self->{methods}->{$name} = $code; # Moose stores meta object here.

    Test::Builder2::Mouse::Util::install_subroutines($self->name,
        $name => $code,
    );
    return;
}

package Test::Builder2::Mouse::Meta::Class;

use Test::Builder2::Mouse::Meta::Method::Constructor;
use Test::Builder2::Mouse::Meta::Method::Destructor;

sub method_metaclass    { $_[0]->{method_metaclass}    || 'Test::Builder2::Mouse::Meta::Method'    }
sub attribute_metaclass { $_[0]->{attribute_metaclass} || 'Test::Builder2::Mouse::Meta::Attribute' }

sub constructor_class { $_[0]->{constructor_class} || 'Test::Builder2::Mouse::Meta::Method::Constructor' }
sub destructor_class  { $_[0]->{destructor_class}  || 'Test::Builder2::Mouse::Meta::Method::Destructor'  }

sub is_anon_class{
    return exists $_[0]->{anon_serial_id};
}

sub roles { $_[0]->{roles} }

sub linearized_isa { @{ get_linear_isa($_[0]->{package}) } }

sub get_all_attributes {
    my($self) = @_;
    my %attrs = map { %{ $self->initialize($_)->{attributes} } } reverse $self->linearized_isa;
    return values %attrs;
}

sub new_object {
    my $self = shift;
    my %args = (@_ == 1 ? %{$_[0]} : @_);

    my $object = bless {}, $self->name;

    $self->_initialize_object($object, \%args);
    return $object;
}

sub _initialize_object{
    my($self, $object, $args, $is_cloning) = @_;

    my @triggers_queue;

    foreach my $attribute ($self->get_all_attributes) {
        my $init_arg = $attribute->init_arg;
        my $slot     = $attribute->name;

        if (defined($init_arg) && exists($args->{$init_arg})) {
            $object->{$slot} = $attribute->_coerce_and_verify($args->{$init_arg}, $object);

            weaken($object->{$slot})
                if ref($object->{$slot}) && $attribute->is_weak_ref;

            if ($attribute->has_trigger) {
                push @triggers_queue, [ $attribute->trigger, $object->{$slot} ];
            }
        }
        elsif(!$is_cloning) { # no init arg, noop while cloning
            if ($attribute->has_default || $attribute->has_builder) {
                if (!$attribute->is_lazy) {
                    my $default = $attribute->default;
                    my $builder = $attribute->builder;
                    my $value =   $builder                ? $object->$builder()
                                : ref($default) eq 'CODE' ? $object->$default()
                                :                           $default;

                    $object->{$slot} = $attribute->_coerce_and_verify($value, $object);

                    weaken($object->{$slot})
                        if ref($object->{$slot}) && $attribute->is_weak_ref;
                }
            }
            elsif($attribute->is_required) {
                $self->throw_error("Attribute (".$attribute->name.") is required");
            }
        }
    }

    if(@triggers_queue){
        foreach my $trigger_and_value(@triggers_queue){
            my($trigger, $value) = @{$trigger_and_value};
            $trigger->($object, $value);
        }
    }

    if($self->is_anon_class){
        $object->{__METACLASS__} = $self;
    }

    return;
}

sub is_immutable {  $_[0]->{is_immutable} }

sub __strict_constructor{ $_[0]->{strict_constructor} }

package Test::Builder2::Mouse::Meta::Role;

sub method_metaclass{ $_[0]->{method_metaclass} || 'Test::Builder2::Mouse::Meta::Role::Method' }

sub is_anon_role{
    return exists $_[0]->{anon_serial_id};
}

sub get_roles { $_[0]->{roles} }

sub add_before_method_modifier {
    my ($self, $method_name, $method) = @_;

    push @{ $self->{before_method_modifiers}{$method_name} ||= [] }, $method;
    return;
}
sub add_around_method_modifier {
    my ($self, $method_name, $method) = @_;

    push @{ $self->{around_method_modifiers}{$method_name} ||= [] }, $method;
    return;
}
sub add_after_method_modifier {
    my ($self, $method_name, $method) = @_;

    push @{ $self->{after_method_modifiers}{$method_name} ||= [] }, $method;
    return;
}

sub get_before_method_modifiers {
    my ($self, $method_name) = @_;
    return @{ $self->{before_method_modifiers}{$method_name} ||= [] }
}
sub get_around_method_modifiers {
    my ($self, $method_name) = @_;
    return @{ $self->{around_method_modifiers}{$method_name} ||= [] }
}
sub get_after_method_modifiers {
    my ($self, $method_name) = @_;
    return @{ $self->{after_method_modifiers}{$method_name} ||= [] }
}

package Test::Builder2::Mouse::Meta::Attribute;

require Test::Builder2::Mouse::Meta::Method::Accessor;

sub accessor_metaclass{ $_[0]->{accessor_metaclass} || 'Test::Builder2::Mouse::Meta::Method::Accessor' }

# readers

sub name                 { $_[0]->{name}                   }
sub associated_class     { $_[0]->{associated_class}       }

sub accessor             { $_[0]->{accessor}               }
sub reader               { $_[0]->{reader}                 }
sub writer               { $_[0]->{writer}                 }
sub predicate            { $_[0]->{predicate}              }
sub clearer              { $_[0]->{clearer}                }
sub handles              { $_[0]->{handles}                }

sub _is_metadata         { $_[0]->{is}                     }
sub is_required          { $_[0]->{required}               }
sub default              { $_[0]->{default}                }
sub is_lazy              { $_[0]->{lazy}                   }
sub is_lazy_build        { $_[0]->{lazy_build}             }
sub is_weak_ref          { $_[0]->{weak_ref}               }
sub init_arg             { $_[0]->{init_arg}               }
sub type_constraint      { $_[0]->{type_constraint}        }

sub trigger              { $_[0]->{trigger}                }
sub builder              { $_[0]->{builder}                }
sub should_auto_deref    { $_[0]->{auto_deref}             }
sub should_coerce        { $_[0]->{coerce}                 }

sub documentation        { $_[0]->{documentation}          }

# predicates

sub has_accessor         { exists $_[0]->{accessor}        }
sub has_reader           { exists $_[0]->{reader}          }
sub has_writer           { exists $_[0]->{writer}          }
sub has_predicate        { exists $_[0]->{predicate}       }
sub has_clearer          { exists $_[0]->{clearer}         }
sub has_handles          { exists $_[0]->{handles}         }

sub has_default          { exists $_[0]->{default}         }
sub has_type_constraint  { exists $_[0]->{type_constraint} }
sub has_trigger          { exists $_[0]->{trigger}         }
sub has_builder          { exists $_[0]->{builder}         }

sub has_documentation    { exists $_[0]->{documentation}   }

sub _process_options{
    my($class, $name, $args) = @_;

    # taken from Class::MOP::Attribute::new

    defined($name)
        or $class->throw_error('You must provide a name for the attribute');

    if(!exists $args->{init_arg}){
        $args->{init_arg} = $name;
    }

    # 'required' requires eigher 'init_arg', 'builder', or 'default'
    my $can_be_required = defined( $args->{init_arg} );

    if(exists $args->{builder}){
        # XXX:
        # Moose refuses a CODE ref builder, but Mouse doesn't for backward compatibility
        # This feature will be changed in a future. (gfx)
        $class->throw_error('builder must be a defined scalar value which is a method name')
            #if ref $args->{builder} || !defined $args->{builder};
            if !defined $args->{builder};

        $can_be_required++;
    }
    elsif(exists $args->{default}){
        if(ref $args->{default} && ref($args->{default}) ne 'CODE'){
            $class->throw_error("References are not allowed as default values, you must "
                              . "wrap the default of '$name' in a CODE reference (ex: sub { [] } and not [])");
        }
        $can_be_required++;
    }

    if( $args->{required} && !$can_be_required ) {
        $class->throw_error("You cannot have a required attribute ($name) without a default, builder, or an init_arg");
    }

    # taken from Test::Builder2::Mouse::Meta::Attribute->new and ->_process_args

    if(exists $args->{is}){
        my $is = $args->{is};

        if($is eq 'ro'){
            $args->{reader} ||= $name;
        }
        elsif($is eq 'rw'){
            if(exists $args->{writer}){
                $args->{reader} ||= $name;
             }
             else{
                $args->{accessor} ||= $name;
             }
        }
        elsif($is eq 'bare'){
            # do nothing, but don't complain (later) about missing methods
        }
        else{
            $is = 'undef' if !defined $is;
            $class->throw_error("I do not understand this option (is => $is) on attribute ($name)");
        }
    }

    my $tc;
    if(exists $args->{isa}){
        $tc = $args->{type_constraint} = Test::Builder2::Mouse::Util::TypeConstraints::find_or_create_isa_type_constraint($args->{isa});
    }

    if(exists $args->{does}){
        if(defined $tc){ # both isa and does supplied
            my $does_ok = do{
                local $@;
                eval{ "$tc"->does($args) };
            };
            if(!$does_ok){
                $class->throw_error("Cannot have both an isa option and a does option because '$tc' does not do '$args->{does}' on attribute ($name)");
            }
        }
        else {
            $tc = $args->{type_constraint} = Test::Builder2::Mouse::Util::TypeConstraints::find_or_create_does_type_constraint($args->{does});
        }
    }

    if($args->{coerce}){
        defined($tc)
            || $class->throw_error("You cannot have coercion without specifying a type constraint on attribute ($name)");

        $args->{weak_ref}
            && $class->throw_error("You cannot have a weak reference to a coerced value on attribute ($name)");
    }

    if ($args->{lazy_build}) {
        exists($args->{default})
            && $class->throw_error("You can not use lazy_build and default for the same attribute ($name)");

        $args->{lazy}      = 1;
        $args->{builder} ||= "_build_${name}";
        if ($name =~ /^_/) {
            $args->{clearer}   ||= "_clear${name}";
            $args->{predicate} ||= "_has${name}";
        }
        else {
            $args->{clearer}   ||= "clear_${name}";
            $args->{predicate} ||= "has_${name}";
        }
    }

    if ($args->{auto_deref}) {
        defined($tc)
            || $class->throw_error("You cannot auto-dereference without specifying a type constraint on attribute ($name)");

        ( $tc->is_a_type_of('ArrayRef') || $tc->is_a_type_of('HashRef') )
            || $class->throw_error("You cannot auto-dereference anything other than a ArrayRef or HashRef on attribute ($name)");
    }

    if (exists $args->{trigger}) {
        ('CODE' eq ref $args->{trigger})
            || $class->throw_error("Trigger must be a CODE ref on attribute ($name)");
    }

    if ($args->{lazy}) {
        (exists $args->{default} || defined $args->{builder})
            || $class->throw_error("You cannot have lazy attribute ($name) without specifying a default value for it");
    }

    return;
}


package Test::Builder2::Mouse::Meta::TypeConstraint;

sub name    { $_[0]->{name}    }
sub parent  { $_[0]->{parent}  }
sub message { $_[0]->{message} }

sub type_parameter           { $_[0]->{type_parameter} }
sub _compiled_type_constraint{ $_[0]->{compiled_type_constraint} }
sub _compiled_type_coercion  { $_[0]->{_compiled_type_coercion}  }

sub __is_parameterized { exists $_[0]->{type_parameter} }
sub has_coercion {       exists $_[0]->{_compiled_type_coercion} }


sub compile_type_constraint{
    my($self) = @_;

    # add parents first
    my @checks;
    for(my $parent = $self->{parent}; defined $parent; $parent = $parent->{parent}){
         if($parent->{hand_optimized_type_constraint}){
            unshift @checks, $parent->{hand_optimized_type_constraint};
            last; # a hand optimized constraint must include all the parents
        }
        elsif($parent->{constraint}){
            unshift @checks, $parent->{constraint};
        }
    }

    # then add child
    if($self->{constraint}){
        push @checks, $self->{constraint};
    }

    if($self->{type_constraints}){ # Union
        my @types = map{ $_->{compiled_type_constraint} } @{ $self->{type_constraints} };
        push @checks, sub{
            foreach my $c(@types){
                return 1 if $c->($_[0]);
            }
            return 0;
        };
    }

    if(@checks == 0){
        $self->{compiled_type_constraint} = \&Test::Builder2::Mouse::Util::TypeConstraints::Any;
    }
    else{
        $self->{compiled_type_constraint} =  sub{
            my(@args) = @_;
            local $_ = $args[0];
            foreach my $c(@checks){
                return undef if !$c->(@args);
            }
            return 1;
        };
    }
    return;
}

sub check {
    my $self = shift;
    return $self->_compiled_type_constraint->(@_);
}


package Test::Builder2::Mouse::Object;

sub BUILDARGS {
    my $class = shift;

    if (scalar @_ == 1) {
        (ref($_[0]) eq 'HASH')
            || $class->meta->throw_error("Single parameters to new() must be a HASH ref");

        return {%{$_[0]}};
    }
    else {
        return {@_};
    }
}

sub new {
    my $class = shift;

    $class->meta->throw_error('Cannot call new() on an instance') if ref $class;

    my $args = $class->BUILDARGS(@_);

    my $meta = Test::Builder2::Mouse::Meta::Class->initialize($class);
    my $self = $meta->new_object($args);

    # BUILDALL
    if( $self->can('BUILD') ) {
        for my $class (reverse $meta->linearized_isa) {
            my $build = Test::Builder2::Mouse::Util::get_code_ref($class, 'BUILD')
                || next;

            $self->$build($args);
        }
    }

    return $self;
}

sub DESTROY {
    my $self = shift;

    return unless $self->can('DEMOLISH'); # short circuit

    local $?;

    my $e = do{
        local $@;
        eval{
            # DEMOLISHALL

            # We cannot count on being able to retrieve a previously made
            # metaclass, _or_ being able to make a new one during global
            # destruction. However, we should still be able to use mro at
            # that time (at least tests suggest so ;)

            foreach my $class (@{ Test::Builder2::Mouse::Util::get_linear_isa(ref $self) }) {
                my $demolish = Test::Builder2::Mouse::Util::get_code_ref($class, 'DEMOLISH')
                    || next;

                $self->$demolish($Test::Builder2::Mouse::Util::in_global_destruction);
            }
        };
        $@;
    };

    no warnings 'misc';
    die $e if $e; # rethrow
}

sub BUILDALL {
    my $self = shift;

    # short circuit
    return unless $self->can('BUILD');

    for my $class (reverse $self->meta->linearized_isa) {
        my $build = Test::Builder2::Mouse::Util::get_code_ref($class, 'BUILD')
            || next;

        $self->$build(@_);
    }
    return;
}

sub DEMOLISHALL;
*DEMOLISHALL = \&DESTROY;

1;
__END__

=head1 NAME

Test::Builder2::Mouse::PurePerl - A Mouse guts in pure Perl

=head1 VERSION

This document describes Mouse version 0.53

=head1 SEE ALSO

L<Test::Builder2::Mouse::XS>

=cut
