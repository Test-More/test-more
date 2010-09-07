package Test::Builder2::Mouse::Meta::Role;
use Test::Builder2::Mouse::Util qw(:meta not_supported); # enables strict and warnings

use Test::Builder2::Mouse::Meta::Module;
our @ISA = qw(Test::Builder2::Mouse::Meta::Module);

sub method_metaclass;

sub _construct_meta {
    my $class = shift;

    my %args  = @_;

    $args{methods}          = {};
    $args{attributes}       = {};
    $args{required_methods} = [];
    $args{roles}            = [];

    my $self = bless \%args, ref($class) || $class;
    if($class ne __PACKAGE__){
        $self->meta->_initialize_object($self, \%args);
    }

    return $self;
}

sub create_anon_role{
    my $self = shift;
    return $self->create(undef, @_);
}

sub is_anon_role;

sub get_roles;

sub calculate_all_roles {
    my $self = shift;
    my %seen;
    return grep { !$seen{ $_->name }++ }
           ($self, map  { $_->calculate_all_roles } @{ $self->get_roles });
}

sub get_required_method_list{
    return @{ $_[0]->{required_methods} };
}

sub add_required_methods {
    my($self, @methods) = @_;
    my %required = map{ $_ => 1 } @{$self->{required_methods}};
    push @{$self->{required_methods}}, grep{ !$required{$_}++ && !$self->has_method($_) } @methods;
    return;
}

sub requires_method {
    my($self, $name) = @_;
    return scalar( grep{ $_ eq $name } @{ $self->{required_methods} } ) != 0;
}

sub add_attribute {
    my $self = shift;
    my $name = shift;

    $self->{attributes}->{$name} = (@_ == 1) ? $_[0] : { @_ };
    return;
}

sub _check_required_methods{
    my($role, $consumer, $args) = @_;

    if($args->{_to} eq 'role'){
        $consumer->add_required_methods($role->get_required_method_list);
    }
    else{ # to class or instance
        my $consumer_class_name = $consumer->name;

        my @missing;
        foreach my $method_name(@{$role->{required_methods}}){
            next if exists $args->{aliased_methods}{$method_name};
            next if exists $role->{methods}{$method_name};
            next if $consumer_class_name->can($method_name);

            push @missing, $method_name;
        }
        if(@missing){
            $role->throw_error(sprintf "'%s' requires the method%s %s to be implemented by '%s'",
                $role->name,
                (@missing == 1 ? '' : 's'), # method or methods
                Test::Builder2::Mouse::Util::quoted_english_list(@missing),
                $consumer_class_name);
        }
    }

    return;
}

sub _apply_methods{
    my($role, $consumer, $args) = @_;

    my $alias    = $args->{-alias};
    my $excludes = $args->{-excludes};

    foreach my $method_name($role->get_method_list){
        next if $method_name eq 'meta';

        my $code = $role->get_method_body($method_name);

        if(!exists $excludes->{$method_name}){
            if(!$consumer->has_method($method_name)){
                # The third argument $role is used in Role::Composite
                $consumer->add_method($method_name => $code, $role);
            }
        }

        if(exists $alias->{$method_name}){
            my $dstname = $alias->{$method_name};

            my $dstcode = $consumer->get_method_body($dstname);

            if(defined($dstcode) && $dstcode != $code){
                $role->throw_error("Cannot create a method alias if a local method of the same name exists");
            }
            else{
                $consumer->add_method($dstname => $code, $role);
            }
        }
    }

    return;
}

sub _apply_attributes{
    #my($role, $consumer, $args) = @_;
    my($role, $consumer) = @_;

    for my $attr_name ($role->get_attribute_list) {
        next if $consumer->has_attribute($attr_name);

        $consumer->add_attribute($attr_name => $role->get_attribute($attr_name));
    }
    return;
}

sub _apply_modifiers{
    #my($role, $consumer, $args) = @_;
    my($role, $consumer) = @_;


    if(my $modifiers = $role->{override_method_modifiers}){
        foreach my $method_name (keys %{$modifiers}){
            $consumer->add_override_method_modifier($method_name => $modifiers->{$method_name});
        }
    }

    for my $modifier_type (qw/before around after/) {
        my $table = $role->{"${modifier_type}_method_modifiers"}
            or next;

        my $add_modifier = "add_${modifier_type}_method_modifier";

        while(my($method_name, $modifiers) = each %{$table}){
            foreach my $code(@{ $modifiers }){
                next if $consumer->{"_applied_$modifier_type"}{$method_name, $code}++; # skip applied modifiers
                $consumer->$add_modifier($method_name => $code);
            }
        }
    }
    return;
}

sub _append_roles{
    #my($role, $consumer, $args) = @_;
    my($role, $consumer) = @_;

    my $roles = $consumer->{roles};

    foreach my $r($role, @{$role->get_roles}){
        if(!$consumer->does_role($r)){
            push @{$roles}, $r;
        }
    }
    return;
}

# Moose uses Application::ToInstance, Application::ToClass, Application::ToRole
sub apply {
    my $self     = shift;
    my $consumer = shift;

    my %args = (@_ == 1) ? %{ $_[0] } : @_;

    my $instance;

    if(Test::Builder2::Mouse::Util::is_a_metaclass($consumer)){  # Application::ToClass
        $args{_to} = 'class';
    }
    elsif(Test::Builder2::Mouse::Util::is_a_metarole($consumer)){ # Application::ToRole
        $args{_to} = 'role';
    }
    else{                                       # Appplication::ToInstance
        $args{_to} = 'instance';
        $instance  = $consumer;

        $consumer = (Test::Builder2::Mouse::Util::class_of($instance) || 'Test::Builder2::Mouse::Meta::Class')->create_anon_class(
            superclasses => [ref $instance],
            cache        => 1,
        );
    }

    if($args{alias} && !exists $args{-alias}){
        $args{-alias} = $args{alias};
    }
    if($args{excludes} && !exists $args{-excludes}){
        $args{-excludes} = $args{excludes};
    }

    $args{aliased_methods} = {};
    if(my $alias = $args{-alias}){
        @{$args{aliased_methods}}{ values %{$alias} } = ();
    }

    if(my $excludes = $args{-excludes}){
        $args{-excludes} = {}; # replace with a hash ref
        if(ref $excludes){
            %{$args{-excludes}} = (map{ $_ => undef } @{$excludes});
        }
        else{
            $args{-excludes}{$excludes} = undef;
        }
    }

    $self->_check_required_methods($consumer, \%args);
    $self->_apply_attributes($consumer, \%args);
    $self->_apply_methods($consumer, \%args);
    $self->_apply_modifiers($consumer, \%args);
    $self->_append_roles($consumer, \%args);


    if(defined $instance){ # Application::ToInstance
        # rebless instance
        bless $instance, $consumer->name;
        $consumer->_initialize_object($instance, $instance, 1);
    }

    return;
}


sub combine {
    my($self, @role_specs) = @_;

    require 'Test/Builder2/Mouse/Meta/Role/Composite.pm'; # we don't want to create its namespace

    my $composite = Test::Builder2::Mouse::Meta::Role::Composite->create_anon_role();

    foreach my $role_spec (@role_specs) {
        my($role_name, $args) = @{$role_spec};
        $role_name->meta->apply($composite, %{$args});
    }
    return $composite;
}

sub add_before_method_modifier;
sub add_around_method_modifier;
sub add_after_method_modifier;

sub get_before_method_modifiers;
sub get_around_method_modifiers;
sub get_after_method_modifiers;

sub add_override_method_modifier{
    my($self, $method_name, $method) = @_;

    if($self->has_method($method_name)){
        # This error happens in the override keyword or during role composition,
        # so I added a message, "A local method of ...", only for compatibility (gfx)
        $self->throw_error("Cannot add an override of method '$method_name' "
                   . "because there is a local version of '$method_name'"
                   . "(A local method of the same name as been found)");
    }

    $self->{override_method_modifiers}->{$method_name} = $method;
}

sub get_override_method_modifier {
    my ($self, $method_name) = @_;
    return $self->{override_method_modifiers}->{$method_name};
}

sub does_role {
    my ($self, $role_name) = @_;

    (defined $role_name)
        || $self->throw_error("You must supply a role name to look for");

    $role_name = $role_name->name if ref $role_name;

    # if we are it,.. then return true
    return 1 if $role_name eq $self->name;
    # otherwise.. check our children
    for my $role (@{ $self->get_roles }) {
        return 1 if $role->does_role($role_name);
    }
    return 0;
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Role - The Mouse Role metaclass

=head1 VERSION

This document describes Mouse version 0.64

=head1 SEE ALSO

L<Moose::Meta::Role>

=cut
