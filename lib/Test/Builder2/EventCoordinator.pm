package Test::Builder2::EventCoordinator;

use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::Singleton',
     'Test::Builder2::CanLoad';

my @Types = qw(early_watchers history formatters late_watchers);


=head1 NAME

Test::Builder2::EventCoordinator - Coordinate events amongst the builders


=head1 SYNOPSIS

    # A builder gets and stores a copy of the singleton
    use Test::Builder2::EventCoordinator;
    my $ec = Test::Builder2::EventCoordinator->singleton;

    # The builder sends it events like assert results and the beginning
    # and end of test streams.
    $ec->post_result($result);  # special case for results
    $ec->post_event($event);

    # The EventCoordinator comes with History and the default Formatter,
    # but they can be replaced or added to.  You can also add watchers of
    # your own devising.
    $events->add_formatters($formatter);
    $events->add_watcher($watcher);


=head1 DESCRIPTION

Test::Builder2 is a federated system of test formatters and assert
generators.  This lets people make new and interesting ways to write
tests and format the results while keeping them coordianted.  The
EventCoordiantor is responsible for that coordination.

Each thing that generates events, usually something that causes
asserts, will report them to the EventCoordinator.  This in turn
reports them to things like History and result Formatters and whatever
else you want to watch events.


=head1 METHODS

=head2 Attributes

These are attributes which can be set and gotten through a method of
the same name.  They can also be passed into C<new>.


=head3 history

The History object which is listening to events.

This is a special case of C<watchers> provided so you can distinguish
between formatters and other watchers.

Defaults to C<< [ Test::Builder2::History->new ] >>.

Unlike other watchers, there is only one history.

=cut

# Specifically not requiring a History subclass so as to allow
# non-Mouse based duck-type implementations.
has history =>
  is            => 'rw',
  isa           => 'Object',
  lazy          => 1,
  default       => sub {
      $_[0]->load("Test::Builder2::History");
      return Test::Builder2::History->new;
  };


=head3 formatters

An array ref of Formatter objects which are listening to events.

This is a special case of C<watchers> provided so you can distinguish
between formatters and other watchers.

Defaults to C<< [ Test::Builder2::Formatter::TAP->new ] >>.

=cut

# Specifically not requiring a Formatter subclass so as to allow
# non-Mouse based implementations.
has formatters =>
  is            => 'rw',
  isa           => 'ArrayRef',
  lazy          => 1,
  default       => sub {
      $_[0]->load("Test::Builder2::Formatter::TAP");
      return [ Test::Builder2::Formatter::TAP->new ];
  };


=head3 early_watchers

An array ref of any additional objects which are listening to events.
They all must do the Test::Builder2::EventWatcher role (or have
equivalent methods).

early_watchers are called first before any other watchers.  This lets
them manipulate the result before a formatter can act on it.

By default there are no early_watchers.

=cut

# Specifically not requiring an EventWatcher subclass so as to allow
# non-Mouse based implementations.
has early_watchers =>
  is            => 'rw',
  isa           => 'ArrayRef',
  default       => sub { [] };


=head3 late_watchers

An array ref of any additional objects which are listening to events.
They all must do the Test::Builder2::EventWatcher role (or have
equivalent methods).

late_watchers are called last after all other watchers.  This lets
them see the result after any manipulations.

By default there are no late_watchers.

=cut

# Specifically not requiring an EventWatcher subclass so as to allow
# non-Mouse based implementations.
has late_watchers =>
  is            => 'rw',
  isa           => 'ArrayRef',
  default       => sub { [] };


=head2 Constructors

These are methods which create or retrieve EventCoordinator objects.

=head3 singleton

    my $ec = Test::Builder2::EventCoordinator->singleton;

Returns the default EventCoordinator.  If you want to be hooked into
the state of the globally active test, use this.

It will contain the History and Formatter singletons.

=cut

sub make_singleton {
    my $class = shift;

    require Test::Builder2::EventCoordinator::Default;
    return Test::Builder2::EventCoordinator::Default->create(
        real_coordinator => $class->create
    );
}

=head3 create

    my $ec = Test::Builder2::EventCoordinator->create(%args);

Creates a new EventCoordinator.

%args corresponds to the L<Attributes>.


=head2 Methods

=head3 post_result

  $ec->post_result($result);

This is a special case of L<post_event> for assert results.

=cut

sub post_result {
    my $self  = shift;
    my $result = shift;

    for my $watcher ($self->all_watchers) {
        $watcher->accept_result($result, $self);
    }
}


=head3 post_event

  $ec->post_event($event);

The C<$ec> will hand the C<$event> around to all its L<watchers>,
along with itself.  See L<all_watchers> for ordering information.

=cut

sub post_event {
    my $self  = shift;
    my $event = shift;

    for my $watcher ($self->all_watchers) {
        $watcher->accept_event($event, $self);
    }
}


=head3 all_watchers

  my @watchers = $ec->all_watchers;

Returns a list of all watchers in the order they will be passed events.

The order is L<early_watchers>, L<history>, L<formatters>, L<late_watchers>.

=cut

sub all_watchers {
    my $self = shift;

    return
      @{ $self->early_watchers },
      $self->history,
      @{ $self->formatters },
      @{ $self->late_watchers };
}

=head3 add_early_watchers

=head3 add_formatters

=head3 add_late_watchers

  $ec->add_early_watchers($watcher1, $watcher2, ...);

Adds new watchers to their respective types.

Use this instead of manipulating the list of watchers directly.


=head3 clear_early_watchers

=head3 clear_formatters

=head3 clear_late_watchers

  $ec->clear_early_watchers;

Removes all watchers of their respective types.

Use this instead of manipulating the list of watchers directly.

=cut

# Create add_ and clear_ methods for all the watchers except history
for my $type (grep { $_ ne 'history' } @Types) {
    my $add = sub {
        my $self = shift;
        push @{ $self->$type }, @_;

        return;
    };

    my $clear = sub {
        my $self = shift;
        my $watchers = $self->$type;

        # Specifically doing this to reuse the same array ref.
        $#{$watchers} = -1;

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

L<Test::Builder2::EventWatcher>, L<Test::Builder2::Event>, L<Test::Builder2::Result>

=cut

no Test::Builder2::Mouse;

1;
