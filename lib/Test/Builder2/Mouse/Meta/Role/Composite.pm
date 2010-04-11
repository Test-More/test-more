package Test::Builder2::Mouse::Meta::Role::Composite;
use Test::Builder2::Mouse::Util; # enables strict and warnings
use Test::Builder2::Mouse::Meta::Role;
our @ISA = qw(Test::Builder2::Mouse::Meta::Role);

sub get_method_list{
    my($self) = @_;
    return keys %{ $self->{methods} };
}

sub add_method {
    my($self, $method_name, $code, $role) = @_;

    if( ($self->{methods}{$method_name} || 0) == $code){
        # This role already has the same method.
        return;
    }

    if($method_name eq 'meta'){
        $self->SUPER::add_method($method_name => $code);
    }
    else{
        # no need to add a subroutine to the stash
        my $roles = $self->{composed_roles_by_method}{$method_name} ||= [];
        push @{$roles}, $role;
        if(@{$roles} > 1){
            $self->{conflicting_methods}{$method_name}++;
        }
        $self->{methods}{$method_name} = $code;
    }
    return;
}

sub get_method_body {
    my($self, $method_name) = @_;
    return $self->{methods}{$method_name};
}

sub has_method {
    # my($self, $method_name) = @_;
    return 0; # to fool _apply_methods() in combine()
}

sub has_attribute{
    # my($self, $method_name) = @_;
    return 0; # to fool _appply_attributes() in combine()
}

sub has_override_method_modifier{
    # my($self, $method_name) = @_;
    return 0; # to fool _apply_modifiers() in combine()
}

sub add_attribute{
    my $self      = shift;
    my $attr_name = shift;
    my $spec      = (@_ == 1 ? $_[0] : {@_});

    my $existing = $self->{attributes}{$attr_name};
    if($existing && $existing != $spec){
        $self->throw_error("We have encountered an attribute conflict with '$attr_name' "
                         . "during composition. This is fatal error and cannot be disambiguated.");
    }
    $self->SUPER::add_attribute($attr_name, $spec);
    return;
}

sub add_override_method_modifier{
    my($self, $method_name, $code) = @_;

    my $existing = $self->{override_method_modifiers}{$method_name};
    if($existing && $existing != $code){
        $self->throw_error( "We have encountered an 'override' method conflict with '$method_name' during "
                          . "composition (Two 'override' methods of the same name encountered). "
                          . "This is fatal error.")
    }
    $self->SUPER::add_override_method_modifier($method_name, $code);
    return;
}

# components of apply()

sub _apply_methods{
    my($self, $consumer, $args) = @_;

    if(exists $self->{conflicting_methods}){
        my $consumer_class_name = $consumer->name;

        my @conflicting = grep{ !$consumer_class_name->can($_) } keys %{ $self->{conflicting_methods} };

        if(@conflicting == 1){
            my $method_name = $conflicting[0];
            my $roles       = Test::Builder2::Mouse::Util::quoted_english_list(map{ $_->name } @{ $self->{composed_roles_by_method}{$method_name} });
            $self->throw_error(
               sprintf q{Due to a method name conflict in roles %s, the method '%s' must be implemented or excluded by '%s'},
                   $roles, $method_name, $consumer_class_name
            );
        }
        elsif(@conflicting > 1){
            my %seen;
            my $roles = Test::Builder2::Mouse::Util::quoted_english_list(
                grep{ !$seen{$_}++ } # uniq
                map { $_->name }
                map { @{$_} } @{ $self->{composed_roles_by_method} }{@conflicting}
            );

            $self->throw_error(
               sprintf q{Due to method name conflicts in roles %s, the methods %s must be implemented or excluded by '%s'},
                   $roles,
                   Test::Builder2::Mouse::Util::quoted_english_list(@conflicting),
                   $consumer_class_name
            );
        }
    }

    $self->SUPER::_apply_methods($consumer, $args);
    return;
}
1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Role::Composite - An object to represent the set of roles

=head1 VERSION

This document describes Mouse version 0.53

=head1 SEE ALSO

L<Moose::Meta::Role::Composite>

=cut
