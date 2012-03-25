package TB2::EventCoordinator;

use TB2::Mouse;
use TB2::Types;
use TB2::threads::shared;

with 'TB2::CanLoad', 'TB2::HasObjectID';

our $VERSION = '1.005000_004';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

my @Types = qw(early_handlers history formatters late_handlers);


=head1 NAME

TB2::EventCoordinator - Coordinate events amongst the builders


=head1 SYNOPSIS

    use TB2::EventCoordinator;
    my $ec = TB2::EventCoordinator->new;

    # The builder sends it events like assert results and the beginning
    # and end of tests.
    $ec->post_event($event);

    # The EventCoordinator comes with History and the default Formatter,
    # but they can be replaced or added to.  You can also add handlers of
    # your own devising.
    $events->add_formatters($formatter);
    $events->add_late_handlers($handler);


=head1 DESCRIPTION

Test::Builder2 is a federated system of test formatters and assert
generators.  This lets people make new and interesting ways to write
tests and format the results while keeping them coordianted.  The
EventCoordiantor is responsible for that coordination.

Each thing that generates events, usually something that causes
asserts, will report them to the EventCoordinator.  This in turn
reports them to things like History and result Formatters and whatever
else you want to handle events.


=head1 METHODS

=head2 Attributes

These are attributes which can be set and gotten through a method of
the same name.  They can also be passed into C<new>.


=head3 history

The History object which is listening to events.

This is a special case of C<handlers> provided so you can distinguish
between formatters and other handlers.

Defaults to C<< [ TB2::History->new ] >>.

Unlike other handlers, there is only one history.

=cut

# Specifically not requiring a History subclass so as to allow
# non-Mouse based duck-type implementations.
has history =>
  is            => 'rw',
  isa           => 'Object',
  lazy          => 1,
  trigger       => sub { shared_clone($_[1]) },
  default       => sub {
      $_[0]->load("TB2::History");
      return shared_clone(TB2::History->new);
  };


=head3 formatters

An array ref of Formatter objects which are listening to events.

This is a special case of C<handlers> provided so you can distinguish
between formatters and other handlers.

Defaults to C<< [ $class->default_formatters ] >>.

The default can be altered by overriding L<default_formatter_class>
and/or L<default_formatters>.

=cut

# Specifically not requiring a Formatter subclass so as to allow
# non-Mouse based implementations.
has formatters =>
  is            => 'rw',
  isa           => 'ArrayRef',
  lazy          => 1,
  trigger       => sub { shared_clone($_[1]) },
  builder       => 'default_formatters';


=head3 early_handlers

An array ref of any additional objects which are listening to events.
They all must do the TB2::EventHandler role (or have
equivalent methods).

early_handlers are called first before any other handlers.  This lets
them manipulate the result before a formatter can act on it.

By default there are no early_handlers.

=cut

# Specifically not requiring an EventHandler subclass so as to allow
# non-Mouse based implementations.
has early_handlers =>
  is            => 'rw',
  isa           => 'ArrayRef',
  trigger       => sub { shared_clone($_[1]) },
  default       => sub { [] };


=head3 late_handlers

An array ref of any additional objects which are listening to events.
They all must do the TB2::EventHandler role (or have
equivalent methods).

late_handlers are called last after all other handlers.  This lets
them see the result after any manipulations.

By default there are no late_handlers.

=cut

# Specifically not requiring an EventHandler subclass so as to allow
# non-Mouse based implementations.
has late_handlers =>
  is            => 'rw',
  isa           => 'ArrayRef',
  trigger       => sub { shared_clone($_[1]) },
  default       => sub { [] };


=head2 Constructors

These are methods which create or retrieve EventCoordinator objects.

=head2 Constructor

=head3 new

    my $ec = TB2::EventCoordinator->new( %args );

Creates a new event coordinator.

%args are the L<Attributes> defined above.

For example, to create an EventCoordinator without a formatter...

    my $ec = TB2::EventCoordinator->new(
        formatters => []
    );


=head2 Methods

=head3 default_formatter_class

    my $formatter_class = $class->default_formatter_class;

Returns the L<TB2::Formatter> subclass to be used for formatting by
default.

Defaults to the TB2_FORMATTER_CLASS environment variable, if set,
or TB2::Formatter::TAP if not.

=cut

sub default_formatter_class {
    return $ENV{TB2_FORMATTER_CLASS} || "TB2::Formatter::TAP";
}


=head3 default_formatters

    my $formatters = $class->default_formatters;

Returns the list of L<formatters> to be used by default.

Defaults to a single instance of the L<default_formatter_class>.

=cut

sub default_formatters {
    my $formatter_class = $_[0]->default_formatter_class;
    $_[0]->load( $formatter_class );
    return shared_clone( [ $formatter_class->new ] );
}


=head3 post_event

  $ec->post_event($event);

The C<$ec> will hand the C<$event> around to all its L<handlers>,
along with itself.  See L<all_handlers> for ordering information.

=cut

sub post_event {
    my $self  = shift;
    my $event = shift;

    $event = shared_clone($event);
    for my $handler ($self->all_handlers) {
        $handler->accept_event($event, $self);
    }
}


=head3 all_handlers

  my @handlers = $ec->all_handlers;

Returns a list of all handlers in the order they will be passed events.

The order is L<early_handlers>, L<history>, L<formatters>, L<late_handlers>.

=cut

sub all_handlers {
    my $self = shift;

    return
      @{ $self->early_handlers },
      $self->history,
      @{ $self->formatters },
      @{ $self->late_handlers };
}

=head3 add_early_handlers

=head3 add_formatters

=head3 add_late_handlers

  $ec->add_early_handlers($handler1, $handler2, ...);

Adds new handlers to their respective types.

Use this instead of manipulating the list of handlers directly.


=head3 clear_early_handlers

=head3 clear_formatters

=head3 clear_late_handlers

  $ec->clear_early_handlers;

Removes all handlers of their respective types.

Use this instead of manipulating the list of handlers directly.

=head3 object_id

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

See L<TB2::HasObjectID>

=cut

# Create add_ and clear_ methods for all the handlers except history
for my $type (grep { $_ ne 'history' } @Types) {
    my $add = sub {
        my $self = shift;
        my @handlers = map { shared_clone($_) } @_;
        push @{ $self->$type }, @handlers;

        return;
    };

    my $clear = sub {
        my $self = shift;
        my $handlers = $self->$type;

        # Specifically doing this to reuse the same array ref.
        $#{$handlers} = -1;

        return;
    };

    no strict 'refs';
    *{"add_".$type}   = $add;
    *{"clear_".$type} = $clear;
}


=head1 THANKS

Thanks to hdp and rjbs who convinced me that an event coordinator was
necessary.  Here is documentation of the historic moment:
L<http://www.flickr.com/photos/xwrn/5334766071/>


=head1 SEE ALSO

L<TB2::EventHandler>, L<TB2::Event>, L<TB2::Result>

=cut

no TB2::Mouse;

1;
