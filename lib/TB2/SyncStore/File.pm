package TB2::SyncStore::File;

use TB2::Mouse;
use TB2::Types;

with 'TB2::HasObjectID';

use Carp;
use Fcntl ':DEFAULT', ':seek', ':flock';


=head1 NAME

TB2::SyncStore::File - store and manage an individual file

=head1 SYNOPSIS

    use TB2::SyncStore::File;

    my $file = TB2::SyncStore::File->new;

    $file->get_lock;
    my $content = $file->read_file;
    $file->write_file($content);
    $file->unlock;

=head1 DESCRIPTION

Manages reading, writing and locking individual files for
L<TB2::SyncStore> across forks.

The file will be deleted when the object is destroyed in the process
which created the file.


=head1 METHODS

=head2 Attributes

=head3 file

The file to write to.

It will be deleted on object destruction in the parent process.

Defaults to a temp file.

=cut

has file =>
  is            => 'ro',
  isa           => 'Str|File::Temp',
  required      => 1,
  default       => sub {
      require File::Temp;

      # We have to manage the filehandle ourselves, so don't let
      # File::Temp open or lock it.
      return File::Temp::tmpnam();
  };

has _fh =>
  is            => 'rw',
  isa           => 'FileHandle',
  lazy          => 1,
  default       => \&_open_file;

has _opened_by_pid =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

has _created_by_pid =>
  is            => 'ro',
  isa           => 'Int',
  default       => $$;


sub _open_file {
    my $self = shift;

    sysopen my $fh, $self->file, O_RDWR|O_CREAT or
      croak "Can't open @{[ $self->file ]} for reading and writing: $!";
    $fh->autoflush(1);

    $self->_opened_by_pid($$);

    return $fh;
}


=head2 Constructors

=head3 new

    my $file = TB2::SyncStore::File->new(%attributes);

Creates a new instance.


=head2 Methods

=head3 fh

    my $fh = $file->fh;

Returns a filehandle to C<< $file->file >> opened for reading and
writing.  The filehandle is guaranteed to be at position 0.

=cut

sub fh {
    my $self = shift;

    # We forked.  Reopen.
    if( $self->_opened_by_pid != $$ ) {
        close $self->_fh;
        $self->_fh( $self->_open_file );
    }

    my $fh = $self->_fh;
    seek $fh, 0, SEEK_SET or croak "Can't seek back to the begining of @{[ $self->file ]}: $!";

    return $fh;
}

=head3 get_lock

    $file->get_lock;

Gets an exclusive lock on the $file.

Throws an exception if the lock fails.

=cut

sub get_lock {
    my $self = shift;

    flock $self->fh, LOCK_EX or croak "Can't get an exclusive lock on @{[ $self->file ]}: $!";

    return;
}

=head3 unlock

    $file->unlock;

Unlocks the $file.

Throws an exception if the unlock fails.

=cut

sub unlock {
    my $self = shift;

    flock $self->fh, LOCK_UN or croak "Can't unlock @{[ $self->file ]}: $!";
}


=head3 read_file

    my $content = $file->read_file;

Returns the $content of C<< $file->file >>.

=cut

sub read_file {
    my $self = shift;

    my $fh = $self->fh;
    return do { local $/; <$fh> };
}


=head3 write_file

    $file->write_file($content);

Writes the $content to C<< $file->file >>.  Existing content will be overwritten.

=cut

sub write_file {
    my $self = shift;
    my $contents = shift;

    my $fh = $self->fh;

    # Clear the file contents (we can't just reopen it, we have to
    # retain the lock).
    truncate $fh, 0;
    seek $fh, 0, SEEK_SET or croak "Can't seek back to the begining of @{[ $self->file ]}: $!";

    print $fh $contents;

    return;
}

sub DESTROY {
    my $self = shift;

    unlink $self->file if $self->_created_by_pid == $$;

    return;
}

no TB2::Mouse;

1;
