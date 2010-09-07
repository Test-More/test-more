package Test::Builder2::Mouse::Meta::Method::Destructor;
use Test::Builder2::Mouse::Util qw(:meta); # enables strict and warnings

sub _empty_DESTROY{ }

sub _generate_destructor{
    my (undef, $metaclass) = @_;

    if(!$metaclass->name->can('DEMOLISH')){
        return \&_empty_DESTROY;
    }

    my $demolishall = '';
    for my $class ($metaclass->linearized_isa) {
        if (Test::Builder2::Mouse::Util::get_code_ref($class, 'DEMOLISH')) {
            $demolishall .= sprintf "%s::DEMOLISH(\$self, \$Test::Builder2::Mouse::Util::in_global_destruction);\n",
                $class,
        }
    }

    my $source = sprintf(<<'END_DESTROY', __LINE__, __FILE__, $demolishall);
#line %d %s
    sub {
        my $self = shift;
        my $e = do{
            local $?;
            local $@;
            eval{
                # demolishall
                %s;
            };
            $@;
        };
        no warnings 'misc';
        die $e if $e; # rethrow
    }
END_DESTROY

    my $code;
    my $e = do{
        local $@;
        $code = eval $source;
        $@;
    };
    die $e if $e;
    return $code;
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Method::Destructor - A Mouse method generator for destructors

=head1 VERSION

This document describes Mouse version 0.64

=head1 SEE ALSO

L<Moose::Meta::Method::Destructor>

=cut
