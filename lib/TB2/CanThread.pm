package TB2::CanThread;

use TB2::Mouse ();
use TB2::Mouse::Role;

use TB2::threads::shared ();


=head1 NAME

TB2::CanThread - A role for an object which must be aware of threading

=head1 SYNOPSIS

    package MyThing;

    use TB2::Mouse;
    with 'TB2::CanThread';

    my $thing = MyThing->new;

    $object = $thing->shared_clone($object);
    $thing->share(\@array);


=head1 DESCRIPTION

This role manages the sharing of objects between threads.

=head1 METHODS

=head2 Attributes

=head2 threads::shared methods

These all work like their L<threads::shared> counterparts.

=head3 share

    $obj->share(\$simple_variable);

=head3 shared_clone

    my $clone = $obj->shared_clone($deep_variable);

=cut

my $real_share = TB2::threads::shared->can("share");
sub share {
    my $self = shift;
    return $real_share->($_[0]);
}

my $real_shared_clone = TB2::threads::shared->can("shared_clone");
sub shared_clone {
    my $self = shift;
    return $real_shared_clone->($_[0]);
}


=head1 SEE ALSO

L<threads::shared>

=cut

1;
