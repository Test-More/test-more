package TB2::TestState;

use TB2::Mouse;
use TB2::Types;

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Carp;

with 'TB2::HasDefault',
     'TB2::CanLoad',
     'TB2::CanThread';

has _coordinators =>
  is            => 'rw',
  isa           => "ArrayRef[Object]",
  # The first one will be added at create() time because triggers don't work on default
  # and we need to delegate when a coordinator is added.
  default       => sub { [] },
  documentation => "A stack of EventCoordinators";

has _coordinator_constructor_args =>
  is            => 'rw',
  isa           => 'HashRef',
  default       => sub { {} },
  documentation => <<END;
Arguments passed to the TestState constructor which are passed on to the coordinator.
END

my $DEFAULT_COORDINATOR_CLASS = 'TB2::EventCoordinator';
has coordinator_class =>
  is            => 'rw',
  isa           => 'Str',  # Grr, ClassName requires the class be loaded
  default       => $DEFAULT_COORDINATOR_CLASS,
  documentation => <<END;
The class to make event coordinators from.
END


=head1 NAME

TB2::TestState - Object which holds the state of the test

=head1 SYNOPSIS

    use TB2::TestState;

    # Get the state of the default test.
    # Usually you'd ask your builder for the TestState object,
    # but we'll get it directly.
    my $state = TB2::TestState->default;

    # Post an event, like an EventCoordinator
    $state->post_event($event);

    # Get the history of the test
    my $history = $state->history;


=head1 DESCRIPTION

All test state resides not in the builder objects but in the TestState
and its attached L<TB2::EventHandler> objects.  TestState
holds onto the current event handlers and passes events along to them.
It also manages subtest state.

For example, when a builder has generated a Result object, it should
post it to the TestState.

    $state->post_event($result);

TestState does everything a L<TB2::EventCoordinator> does.
It delegates to a stack of EventCoordinators, one for each layer of
subtesting.

TestState has a default object to hold the state of the default
test.  Builders should use C<< TB2::TestState->default >>
to get the TestState if they want to play nice with others.  You can
also create your own test states with
C<<TB2::TestState->create >>.

=head1 METHODS

=head2 Constructors

Because TestState is a default, it does not provide a B<new> to
avoid confusion.  It instead has B<create> and B<default>.

=head3 create

    my $state = TB2::TestState->create(%event_coordinator_args);

Create a new test state.

C<%event_coordinator_args> are passed to the constructor when it
creates new event coordinators.  This lets you pass in different
formatters and handlers.

    # Make a test state with no formatter
    my $state = TB2::TestState->create(
        formatters => []
    );


=head3 default

    my $state = TB2::TestState->default;

Retrieve the shared TestState.

You should use this if you want to coordinate with other test libraries.

=cut

# Override create() to add the first coordinator.
# Mouse attributes don't provide enough flexibility to have both a default
# and the trigger to do the delegation.
sub create {
    my $class = shift;
    my %args = @_;

    # Roles inject methods, so we can't call SUPER. :(
    my $self = $class->TB2::Mouse::Object::new(@_);

    # Store our constructor arguments
    $self->_coordinator_constructor_args(\%args);

    $self->push_coordinator;

    return $self;
}


sub make_default {
    my $class = shift;
    my $state = $class->create;
    return $state->shared_clone($state);
}


=head2 EventCoordinator methods

TestState delegates to a stack of EventCoordinators.  It does all the
methods of L<TB2::EventCoordinator>.


=head2 Stack management

TestState maintains state in a stack of EventCoordinators.  Each item
in the stack is isolated from another (unless they decide to share
EventHandlers).

One can add a coordinator to the stack to set up an isolated test
state and remove it to restore the original state.  This is useful
both for testing tests (see L<TB2::Tester>) and for running
subtests in isolation.

=head3 push_coordinator

    my $event_coordinator = $state->push_coordinator;
    my $event_coordinator = $state->push_coordinator($event_coordinator);

Add an $event_coordinator to the stack.  This will become the new delegate.

If an $event_coordinator is not passed in, a new one will be made using
the arguments originally passed into L<create>.

=cut

sub push_coordinator {
    my $self = shift;

    my $ec;
    if( !@_ ) {
        my $coordinator_class = $self->coordinator_class;
        $self->load( $coordinator_class );

        $ec = $coordinator_class->new( %{ $self->_coordinator_constructor_args } );
    }
    else {
        $ec = shift;
    }

    $ec = $self->shared_clone($ec);
    push @{ $self->_coordinators }, $ec; 

    # Do the delegation every time we add a new coordinator in case it's
    # a subclass that added methods.
    $self->_delegate_to_current_coordinator;

    return $ec;
}


=head3 pop_coordinator

    my $event_coordinator = $state->pop_coordinator;

This will remove the current coordinator from the stack.  Test state
will be delegated to the coordinator below it.

An exception will be thrown if the final coordinator is attempted to
be removed.

=cut

sub pop_coordinator {
    my $self = shift;

    my $coordinators = $self->_coordinators;
    croak "The last coordinator cannot be popped" if @$coordinators == 1;

    return pop @$coordinators;
}


=head3 current_coordinator

    my $ec = $state->current_coordinator;

Returns the current L<TB2::EventCoordinator> which is being
delegated to.

=cut

sub current_coordinator {
    $_[0]->_coordinators->[-1];
}


# Find the event coordinator to check with isa/can.
# Do it carefuly because this might fire during globlal destruction
# and $self->_coordinators might already be cleaned up.
sub _ec {
    my $self = shift;

    # It's a class
    return $DEFAULT_COORDINATOR_CLASS if !ref $self;

    # It doesn't have coordinators
    my $coordinators = $self->_coordinators;
    return $DEFAULT_COORDINATOR_CLASS if !$coordinators;

    my $ec = $coordinators->[-1];
    return defined $ec ? $ec : $DEFAULT_COORDINATOR_CLASS;
}


# Convince isa() that we act like an EventCoordinator
sub isa {
    my($self, $want) = @_;

    my $ec = $self->_ec;
    return 1 if $ec->isa($want);
    return $self->SUPER::isa($want);
}

# Convince can() that we act like an EventCoordinator
sub can {
    my($self, $want) = @_;

    my $ec = $self->_ec;
    return 1 if $ec->can($want);
    return $self->SUPER::can($want);
}


# Set up delegation to the current coordinator.
sub _delegate_to_current_coordinator {
    my $self  = shift;

    my $delegate = $self->_coordinators->[-1];
    my $meta = $self->meta;
    foreach my $name( $delegate->meta->get_all_method_names ) {
        # Check what we can do without the delegate.
        # And don't redelegate
        next if $self->SUPER::can($name);

        # Don't delegate private methods
        next if $name =~ /^_/;

        $meta->add_method($name => sub {
            my $self = shift;
            $self->_coordinators->[-1]->$name(@_);
        });
    }

    return;
}


my %special_handlers = (
    'subtest_start' => \&handle_subtest_start,
    'subtest_end'   => \&handle_subtest_end,
);
sub post_event {
    my $self  = shift;

    # Don't shift to preserve @_ so we can pass it along in its entirety.
    my($event) = @_;

    if( my $code = $special_handlers{$event->event_type} ) {
        $self->$code(@_);
    }
    else {
        $self->_coordinators->[-1]->post_event(@_);
    }
}

sub handle_subtest_start {
    my $self  = shift;

    # Don't shift to preserve @_ so we can pass it along in its entirety.
    my($event) = @_;

    # Add nesting information
    $event->depth( $self->_depth + 1 ) unless defined $event->depth;

    my $current_ec = $self->current_coordinator;

    # Post the event to the current level
    $current_ec->post_event(@_);

    # Ask all the handlers in the current coordinator to supply handlers for the subtest.
    # Retain the order of each handler.
    my $subtest_ec = $current_ec->new(
        formatters      => [map { $_->subtest_handler($event) } @{$current_ec->formatters}],
        history         => $current_ec->history->subtest_handler($event),
        early_handlers  => [map { $_->subtest_handler($event) } @{$current_ec->early_handlers}],
        late_handlers   => [map { $_->subtest_handler($event) } @{$current_ec->late_handlers}],
    );

    # Add a new level of testing
    $self->push_coordinator($subtest_ec);

    return;
}


sub handle_subtest_end {
    my $self  = shift;

    # Don't shift to preserve @_ so we can pass it along in its entirety.
    my($event) = @_;

    # Pop the subtest
    my $subtest_ec = $self->pop_coordinator;

    # Attach the subtest history to the event.  If somebody else already
    # did so, honor that.
    $event->history( $subtest_ec->history ) unless $event->history;

    # Post the event to the current level
    $self->current_coordinator->post_event(@_);

    return;
}


sub _depth {
    return @{ $_[0]->_coordinators } - 1;
}

# Do not make it immutable, we need to add delegate methods dynamically.
no TB2::Mouse;


=head1 SEE ALSO

L<TB2::EventCoordinator> which TestState delegates to under the hood.

L<TB2::EventHandler> which handle events.

L<TB2::Formatter> which handle output.

L<TB2::History> which stores events for reference.

=cut

1;
