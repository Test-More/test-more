package TB2::Stack;

use 5.008001;
use TB2::Mouse;
use TB2::Types;

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


use Carp qw(confess);


=head1 NAME

TB2::Stack - A stack object to be used when you need a stack of things.

=head1 SYNOPSIS

   # TODO

   use TB2::Stack;
   my $stack = TB2::Stack->new;
   

=head1 DESCRIPTION

A generic stack object that centralizes the idea of a stack. 

=head1 Methods


=head2 type

This is a read only attribute that is to be specified at creation if you 
need to have a stack that only contains a specific type of items. 

Because this is a stack the value supplied for type is expected to be the
subtype for ArrayRef. So, for example, if type => 'Str' then items will
be of type ArrayRef[Str], if type => undef then items will just remain
of type ArrayRef. Due to the way that the type system works you can only
specify the inital value of the item, no complex types can be specified.

Default: undef implying that any item can be contained in the stack.

=cut

has type => 
   is           => 'ro',
   isa          => 'Maybe[Str]',
   default      => undef,
;

# if type is specified re-write the attribute with one of the right type. 
# [NOTE] idealy this should only overwrite the type, of the existing attr, but I
#        was not able to alter $self->meta->get_attribute('items')->type_constraint
#        and have the changes stick. I'm sure that it's possible but I cant' get it to work.
sub BUILD {
    my $self = CORE::shift;
    if ( defined $self->type ) {
        my $type = sprintf q{ArrayRef[%s]}, $self->type;
        my $value = $self->items ; # save off the value to plug it in later

        delete $self->meta->{attributes}->{items}; #remove the old items attribute to reduce confusion

        my $items = $self->meta->add_attribute( 'items' => is  => 'rw',
                                                           isa => $type,
                                              );
        $items->set_value($self, $value ) if defined $value;
    }
}

=head2 items

    my $items = $stack->items;

Returns an array ref of the TB2::AssertRecord objects on
the stack.

=cut

has items =>
  is            => 'rw',
  isa           => 'ArrayRef',
  default       => sub { [] }
;

=head2 count

Returns the count of the items in the stack.

=cut

sub count {
    scalar( @{ CORE::shift->items } );
}

=head2 pop 

Remove the last element from the items stack and return it.

=cut 

sub pop {
    pop @{ CORE::shift->items };
}

=head2 shift 

Remove the first element of the items stack, and return it.

=cut

sub shift {
    CORE::shift @{ CORE::shift->items };
}

=head2 splice 

!!!! CURRENTLY NOT IMPLIMENTED AS THERE COULD BE ISSUES WITH THREADS !!!!

Add or remove elements anywhere in an array

=cut

sub splice { }

=head2 unshift 

Prepend item(s) to the beginning of the items stack.

=cut

sub unshift {
    my $self = CORE::shift;
    # can not use 'unshift' like pop/shift as you need to trip the type check
    $self->items([ @_, @{ $self->items } ]);
}

=head2 push 

Append one or more elements to the items stack.

=cut

sub push {
    my $self = CORE::shift;
    # can not use 'push' like pop/shift as you need to trip the type check
    $self->items([ @{ $self->items }, @_ ]);
}


#TODO: would a map & grep method be sane?

no TB2::Mouse;
1;
