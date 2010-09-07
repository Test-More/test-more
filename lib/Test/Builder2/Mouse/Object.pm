package Test::Builder2::Mouse::Object;
use Test::Builder2::Mouse::Util qw(does dump meta); # enables strict and warnings

sub new;
sub BUILDARGS;
sub BUILDALL;

sub DESTROY;
sub DEMOLISHALL;

1;
__END__

=head1 NAME

Test::Builder2::Mouse::Object - The base object for Mouse classes

=head1 VERSION

This document describes Mouse version 0.64

=head1 METHODS

=head2 C<< new (Arguments) -> Object >>

Instantiates a new C<Test::Builder2::Mouse::Object>. This is obviously intended for subclasses.

=head2 C<< BUILDARGS (Arguments) -> HashRef >>

Lets you override the arguments that C<new> takes. Return a hashref of
parameters.

=head2 C<< BUILDALL (\%args) >>

Calls C<BUILD> on each class in the class hierarchy. This is called at the
end of C<new>.

=head2 C<< BUILD (\%args) >>

You may put any business logic initialization in BUILD methods. You don't
need to redispatch or return any specific value.

=head2 C<< DEMOLISHALL >>

Calls C<DEMOLISH> on each class in the class hierarchy. This is called at
C<DESTROY> time.

=head2 C<< DEMOLISH >>

You may put any business logic deinitialization in DEMOLISH methods. You don't
need to redispatch or return any specific value.


=head2 C<< does ($role_name) -> Bool >>

This will check if the invocant's class B<does> a given C<$role_name>.
This is similar to "isa" for object, but it checks the roles instead.

=head2 C<< dump ($maxdepth) -> Str >>

From the Moose POD:

    C'mon, how many times have you written the following code while debugging:

     use Data::Dumper; 
     warn Dumper $obj;

    It can get seriously annoying, so why not just use this.

The implementation was lifted directly from Moose::Object.

=head1 SEE ALSO

L<Moose::Object>

=cut

