package TB2::ThreadSafeFilehandleAccessor;

use TB2::Mouse;
use TB2::Mouse::Util::TypeConstraints;


=head1 NAME

=head1 SYNOPSIS

  package Something::That::Stores::Filehandles;

  use TB2::Mouse;
  use TB2::ThreadSafeFilehandleAccessor fh_accessors => [qw(this_fh that_fh)];

  my $obj = Something::That::Stores::Filehandles->new(
      this_fh   => \*STDOUT,
      that_fh   => \*STDERR,
  );

  use threads;
  use threads::shared;
  $obj = shared_clone($obj);

=head1 DESCRIPTION

This provides accessors specially written so objects can store and
access filehandles without storing them internally.  This is necessary
if the object is to be shared across threads.

All structures which are shared between threads must have all their
internal values and objects also be shared.  Filehandles cannot be
shared.  This presents a bit of a problem for L<TB2::Formatter>
objects which contain L<TB2::Streamer> objects which contain a
filehandle.

=head2 How To Use It

    use TB2::ThreadSafeFilehandleAccessor fh_accessors => [@names];

This will create an accessor for each name in @names.


=head2 Limitations & bugs

The main limitation is changes to the filehandles in a thread will not
be shared across threads or with the parent.

The filehandles will not be cleaned up on object destruction.  This
may hold the filehandle open and prevent the file from being flushed
to the disk until the process exits.

=cut

my %Filehandle_Storage;  # unshared storage of filehandles
my $Storage_Counter = 1; # a counter to use as a key

# This "type" exists to intercept incoming filehandles.
# The filehandle goes into %Filehandle_Storage and the
# object gets the key.
subtype 'TB2::Filehandle2Key' =>
  as 'Int';
coerce 'TB2::Filehandle2Key' =>
  from 'Defined',
  via {
      my $key = $Storage_Counter++;
      $Filehandle_Storage{$key} = $_;
      return $key;
  };

sub import {
    my $class = shift;
    my $caller = caller;

    my %args = @_;
    $args{fh_accessors} ||= [];

    for my $name (@{$args{fh_accessors}}) {
        my $meta = $caller->meta;

        $meta->add_attribute( $name =>
            is            => 'rw',
            isa           => 'TB2::Filehandle2Key',
            coerce        => 1,
        );

        $meta->add_around_method_modifier( $name => sub {
            my $orig = shift;
            my $self = shift;

            if( @_ ) {                  # setting
                return $self->$orig(@_);
            }
            else {                      # getting
                my $key = $self->$orig;
                return if !defined $key;
                return $Filehandle_Storage{$key};
            }
        });
    }
}


=head1 SEE ALSO

L<TB2::Streamer::Print> is the main target for this.

=cut

no TB2::Mouse;
no TB2::Mouse::Util::TypeConstraints;

1;
