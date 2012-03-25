package TB2::HasObjectID;

require TB2::Mouse;
use TB2::Mouse::Role;

our $VERSION = '1.005000_003';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::HasObjectID - a unique id in the current process

=head1 SYNOPSIS

    package My::Thing;

    use TB2::Mouse;
    with "TB2::HasObjectID";

    my $thing = My::Thing->new;
    my $id = $thing->object_id;

=head1 DESCRIPTION

Provides a method for generating unique ids for many TB2 objects.

Useful if, for example, an EventHandler posts its own events and
doesn't want to process them twice.

=head3 object_id

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

=cut

my $Counter = int rand(1_000_000);
has object_id =>
  is            => 'ro',
  isa           => 'Str',
  lazy          => 1,
  default       => sub {
      my $self = shift;

      # Include the class in case somebody else decides to use
      # just an integer.
      return ref($self) . '-' . $Counter++;
  }
;

no TB2::Mouse;
no TB2::Mouse::Role;

1;
