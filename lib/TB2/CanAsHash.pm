package TB2::CanAsHash;

use TB2::Mouse ();
use TB2::Mouse::Role;
use Scalar::Util ();
with 'TB2::CanTry';


=head1 NAME

TB2::CanAsHash - a role to dump an object as a hash

=head1 SYNOPSIS

    package Some::Object;

    use TB2::Mouse;
    with 'TB2::CanAsHash';


=head2 Methods

=head3 as_hash

    my $data = $object->as_hash;

Returns all the attributes and data associated with this C<$object> as
a hash of attributes and values.

Attributes with undefined values will not be dumped.

It is recursive, objects encountered will have their as_hash method
called, if they have one.

The intent is to provide a way to dump all the information in an
object without having to call methods which may or may not exist.

Uses L</keys_for_as_hash> to determine which attributes to access.

=cut

sub as_hash {
    my $self = shift;

    my %hash;
    for my $key (@{$self->keys_for_as_hash}) {
        my $val = $self->$key();

        next unless defined $val;

        $val = $val->as_hash if defined Scalar::Util::blessed($val) && $val->can("as_hash");

        $hash{$key} = $val if defined $val;
    }

    return \%hash;
}


=head3 keys_for_as_hash

    my $keys = $object->keys_for_as_hash;

Returns an array ref of keys for C<as_hash> to use as keys and methods
to call on the $object for the key's value.

By default it uses the $object's non-private attributes.  That should
be sufficient for most cases.

=cut

my %Attributes;
sub keys_for_as_hash {
    my $self = shift;
    my $class = ref $self;
    return $Attributes{$class} ||= [
        grep !/^_/, map { $_->name } $class->meta->get_all_attributes
    ];
}

no TB2::Mouse::Role;

1;
