package TB2::SyncStore;

use 5.008001;

use TB2::Mouse;
use TB2::Types;

with 'TB2::HasObjectID';

use Storable ();
use TB2::SyncStore::File;


=head1 NAME

TB2::SyncStore - Storage to sync the test state between processes

=head1 SYNOPSIS

    use TB2::SyncStore;

    my $store = TB2::SyncStore->new;

    my $stored_object = $store->read_and_lock($object);
    $store->write_and_unlock($object);

=head1 DESCRIPTION

Handles storage of objects to allow synchonization of test state
between different processes.

Usually used by L<TB2::TestState> to store and retrieve
L<TB2::EventCoordinator> objects between forked processes.

=head1 METHODS

=head2 Constructors

=head3 new

    my $store = TB2::SyncStore->new;

Creates a new TB2::SyncStore object.

=head2 Attributes

=head3 directory

Directory where objects will be stored.

=cut

has directory =>
  is            => 'ro',
  isa           => 'File::Temp::Dir',
  default       => sub {
      require File::Temp;
      return File::Temp->newdir;
  };

has _id_to_store =>
  is            => 'ro',
  isa           => 'HashRef[TB2::SyncStore::File]',
  default       => sub { {} };


=head2 Methods

=head3 read_and_lock

    $store->read_and_lock($object);

C<$object> must do the L<TB2::HasObjectID> role.

=cut

sub read_and_lock {
    my $self = shift;
    my $object = shift;

    my $store = $self->_store_for_id($object->object_id);
    $store->get_lock;
    return Storable::thaw($store->read_file);
}


sub _store_for_id {
    my $self = shift;
    my $id   = shift;

    my $id_to_store = $self->_id_to_store;
    if( my $store = $id_to_store->{$id} ) {
        return $store;
    }
    else {
        return $id_to_store->{$id} = TB2::SyncStore::File->new;
    }
}


=head3 write_and_unlock

    my $stored_object = $store->write_and_unlock($object);

C<$object> must do the L<TB2::HasObjectID> role.

=cut

sub write_and_unlock {
    my $self = shift;
    my $obj  = shift;

    my $store = $self->_store_for_id($obj->object_id);
    $store->write_file( Storable::freeze($obj) );
    $store->unlock;

    return;
}

no TB2::Mouse;

1;
