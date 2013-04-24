package TB2::Event::Generic;

use strict;
use warnings;

use Carp;
use TB2::Mouse;
with 'TB2::Event';


=head1 NAME

TB2::Event::Generic - A container for any type of event

=head1 SYNOPSIS

     use TB2::Event::Generic;

     my $event = TB2::Event::Generic->new( $event->as_hash );

=head1 DESCRIPTION

This is a container for any type of event.  Its primary purpose is to
receive events serialized using C<< TB2::Event->as_hash >>.

All attributes are read only.

=head1 SEE ALSO

See L<TB2::Formatter::JSON> for an example of use.

=cut


sub build_event_type {
    croak("The event_type must be defined in the constructor");
}

# Ensure that all attributes are dumped via as_hash
my @Attributes = grep !/^_/, map { $_->name } __PACKAGE__->meta->get_all_attributes;
sub keys_for_as_hash {
    my $self = shift;

    return \@Attributes;
}

sub BUILDARGS {
    my $class = shift;
    my %args = @_;

    # Generate attributes for whatever they pass in
    for my $attribute (keys %args) {
        next if $class->can($attribute);
        has $attribute =>
          is    => 'ro';
        push @Attributes, $attribute;
    }

    return \%args;
}

1;
