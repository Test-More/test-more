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

    # Don't coordinate with other threads
    my $uncoordinated = MyThing->new(
        coordinate_threads => 0
    );

    # Coordinate with other threads by default
    my $coordinated = MyThing->new;

    # If coordinate_threads are on and threads are loaded, these will
    # do their thing.  Otherwise they are no-ops.
    $object = $coordinated->shared_clone($object);
    $coordianted->lock($thing);
    $coordianted->share(\@array);


=head1 DESCRIPTION

This role manages the sharing of objects between threads.

=head1 METHODS

=head2 Attributes

=head3 coordinate_threads

If true, this TestState will coordinate its events across threads.

If false, events in child threads will not be seen by other threads.
Each thread will have a detached state.

Default is true, to coordinate.

This cannot be changed once the TestState has been constructed.

=cut

has coordinate_threads =>
  is            => 'ro',
  isa           => 'Bool',
  default       => sub { $INC{"threads.pm"} ? 1 : 0 };


=head2 threads::shared methods

These all work like their L<threads::shared> counterparts I<if and
only if> C<< $obj->coordinate_threads >> is true.  Otherwise they are no-ops.

=head3 share

    $obj->share(\$simple_variable);

=head3 shared_clone

    my $clone = $obj->shared_clone($deep_variable);

If C<< $obj->coordinate_threads >> is false, this will simply return
the C<$variable>.

=cut

my $real_share = TB2::threads::shared->can("share");
sub share {
    my $self = shift;
    return $self->coordinate_threads ? $real_share->($_[0]) : $_[0];
}

my $real_shared_clone = TB2::threads::shared->can("shared_clone");
sub shared_clone {
    my $self = shift;
    return $self->coordinate_threads ? $real_shared_clone->($_[0]) : $_[0];
}


=head3 lock

    lock($var) if $obj->coordinate_threads;

Use the L<normal Perl lock() function|perlfunc/lock> if and only if
C<<$obj->coordinate_threads>> is true.

Unfortunately, we cannot provide a lock() method to do this for you.
The scope of the lock is lock()'s lexical.


=head1 SEE ALSO

L<threads::shared>

=cut

1;
