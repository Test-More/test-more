package Test::Builder2::Mouse::Meta::Role::Method;
use Test::Builder2::Mouse::Util; # enables strict and warnings

use Test::Builder2::Mouse::Meta::Method;
our @ISA = qw(Test::Builder2::Mouse::Meta::Method);

sub _new{
    my($class, %args) = @_;
    my $self = bless \%args, $class;

    if($class ne __PACKAGE__){
        $self->meta->_initialize_object($self, \%args);
    }
    return $self;
}

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Meta::Role::Method - A Mouse Method metaclass for Roles

=head1 VERSION

This document describes Mouse version 0.64

=head1 SEE ALSO

L<Moose::Meta::Role::Method>

=cut

