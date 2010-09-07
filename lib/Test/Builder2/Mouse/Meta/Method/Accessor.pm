package Test::Builder2::Mouse::Meta::Method::Accessor;
use Test::Builder2::Mouse::Util qw(:meta); # enables strict and warnings

sub _inline_slot{
    my(undef, $self_var, $attr_name) = @_;
    return sprintf '%s->{q{%s}}', $self_var, $attr_name;
}

sub _generate_accessor_any{
    my($method_class, $type, $attribute, $class) = @_;

    my $name          = $attribute->name;
    my $default       = $attribute->default;
    my $constraint    = $attribute->type_constraint;
    my $builder       = $attribute->builder;
    my $trigger       = $attribute->trigger;
    my $is_weak       = $attribute->is_weak_ref;
    my $should_deref  = $attribute->should_auto_deref;
    my $should_coerce = (defined($constraint) && $constraint->has_coercion && $attribute->should_coerce);

    my $compiled_type_constraint = defined($constraint) ? $constraint->_compiled_type_constraint : undef;

    my $self  = '$_[0]';
    my $slot  = $method_class->_inline_slot($self, $name);;

    my $accessor = sprintf(qq{package %s;\n#line 1 "%s-accessor for %s (%s)"\n}, $class->name, $type, $name, __FILE__)
                 . "sub {\n";

    if ($type eq 'rw' || $type eq 'wo') {
        if($type eq 'rw'){
            $accessor .= 
                'if (scalar(@_) >= 2) {' . "\n";
        }
        else{ # writer
            $accessor .= 
                'if(@_ < 2){ Carp::confess("Not enough arguments for the writer of '.$name.'") }'.
                '{' . "\n";
        }
                
        my $value = '$_[1]';

        if (defined $constraint) {
            if ($should_coerce) {
                $accessor .=
                    "\n".
                    'my $val = $constraint->coerce('.$value.');';
                $value = '$val';
            }
            $accessor .= 
                "\n".
                '$compiled_type_constraint->('.$value.') or
                    $attribute->_throw_type_constraint_error('.$value.', $constraint);' . "\n";
        }

        # if there's nothing left to do for the attribute we can return during
        # this setter
        $accessor .= 'return ' if !$is_weak && !$trigger && !$should_deref;

        $accessor .= "$slot = $value;\n";

        if ($is_weak) {
            $accessor .= "Scalar::Util::weaken($slot) if ref $slot;\n";
        }

        if ($trigger) {
            $accessor .= '$trigger->('.$self.', '.$value.');' . "\n";
        }

        $accessor .= "}\n";
    }
    elsif($type eq 'ro') {
        $accessor .= 'Carp::confess("Cannot assign a value to a read-only accessor") if scalar(@_) >= 2;' . "\n";
    }
    else{
        $class->throw_error("Unknown accessor type '$type'");
    }

    if ($attribute->is_lazy and $type ne 'wo') {
        my $value;

        if (defined $builder){
            $value = "$self->\$builder()";
        }
        elsif (ref($default) eq 'CODE'){
            $value = "$self->\$default()";
        }
        else{
            $value = '$default';
        }

        $accessor .= "els" if $type eq 'rw';
        $accessor .= "if(!exists $slot){\n";
        if($should_coerce){
            $accessor .= "$slot = \$constraint->coerce($value)";
        }
        elsif(defined $constraint){
            $accessor .= "my \$tmp = $value;\n";

            $accessor .= "\$compiled_type_constraint->(\$tmp)";
            $accessor .= " || \$attribute->_throw_type_constraint_error(\$tmp, \$constraint);\n";
            $accessor .= "$slot = \$tmp;\n";
        }
        else{
            $accessor .= "$slot = $value;\n";
        }
        if ($is_weak) {
            $accessor .= "Scalar::Util::weaken($slot) if ref $slot;\n";
        }
        $accessor .= "}\n";
    }

    if ($should_deref) {
        if ($constraint->is_a_type_of('ArrayRef')) {
            $accessor .= "return \@{ $slot || [] } if wantarray;\n";
        }
        elsif($constraint->is_a_type_of('HashRef')){
            $accessor .= "return \%{ $slot || {} } if wantarray;\n";
        }
        else{
            $class->throw_error("Can not auto de-reference the type constraint " . $constraint->name);
        }
    }

    $accessor .= "return $slot;\n}\n";

    #print $accessor, "\n";
    my $code;
    my $e = do{
        local $@;
        $code = eval $accessor;
        $@;
    };
    die $e if $e;

    return $code;
}

sub _generate_accessor{
    #my($self, $attribute, $metaclass) = @_;
    my $self = shift;
    return $self->_generate_accessor_any(rw => @_);
}

sub _generate_reader {
    #my($self, $attribute, $metaclass) = @_;
    my $self = shift;
    return $self->_generate_accessor_any(ro => @_);
}

sub _generate_writer {
    #my($self, $attribute, $metaclass) = @_;
    my $self = shift;
    return $self->_generate_accessor_any(wo => @_);
}

sub _generate_predicate {
    #my($self, $attribute, $metaclass) = @_;
    my(undef, $attribute) = @_;

    my $slot = $attribute->name;
    return sub{
        return exists $_[0]->{$slot};
    };
}

sub _generate_clearer {
    #my($self, $attribute, $metaclass) = @_;
    my(undef, $attribute) = @_;

    my $slot = $attribute->name;
    return sub{
        delete $_[0]->{$slot};
    };
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Method::Accessor - A Mouse method generator for accessors

=head1 VERSION

This document describes Mouse version 0.64

=head1 SEE ALSO

L<Moose::Meta::Method::Accessor>

=cut
