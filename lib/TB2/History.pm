package TB2::History;

use Carp;
use TB2::Mouse;
use TB2::Mouse::Util::TypeConstraints qw(class_type);
use TB2::Types;
use TB2::threads::shared;

with 'TB2::EventHandler',
     'TB2::CanTry',
     'TB2::CanLoad';

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::History - Holds information about the state of the test

=head1 SYNOPSIS

    use TB2::History;

    # An EventCoordinator contains a History object by default
    my $ec = TB2::EventCoordinator->create();

    my $pass  = TB2::Result->new_result( pass => 1 );
    $ec->post_event( $pass );
    $ec->history->can_succeed;   # true

    my $result  = TB2::Result->new_result( pass => 0 );
    $ec->post_event( $pass );
    $ec->history->can_succeed;   # false


=head1 DESCRIPTION

TB2::History records information and statistics about the state of the
test.  It watches and analyses events as they happen.  It is used to
get information about the state of the test such as has it started,
has it ended, is it passing, how many tests have run and so on.

The history for a test is usually accessed by going through the
L<TB2::TestState> C<history> accessor.

To save memory it does not, by default, store the complete history of
all events.

Each subtest gets its own L<TB2::EventCoordinator> and thus its own
TB2::History object.

It is a L<TB2::EventHandler>.

=head1 METHODS

=head2 Constructors

=head3 new

    my $history = TB2::History->new;

Creates a new, unique History object.

new() takes the following options.

=head3 store_events

If true, $history will keep a complete record of all test events
accessible via L<events> and L<results>.  This will cause memory usage
to grow over the life of the test.

If false, $history will discard events and only keep a summary of
events.  L<events> and L<results> will throw an exception if called.

Defaults to false, events are not stored by default.

=cut

has store_events =>
  is            => 'ro',
  isa           => 'Bool',
  default       => 0
;


=head2 Misc

=head3 object_id

    my $id = $thing->object_id;

Returns an identifier for this object unique to the running process.
The identifier is fairly simple and easily predictable.

See L<TB2::HasObjectID>

=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set

=head2 Events

=head3 events

    my $events = $history->events;

An array ref of all events seen.

By default, no events are stored and this will throw an exception
unless C<< $history->store_events >> is true.

=head3 last_event

    my $event = $history->last_event;

Returns the last event seen.

=cut

has last_event => (
    is          => 'rw',
    does        => 'TB2::Event',
);

sub event_storage_class {
    return $_[0]->store_events ? "TB2::History::EventStorage" : "TB2::History::NoEventStorage";
}

has event_storage =>
  is            => 'ro',
  isa           => class_type('TB2::History::EventStorage'),
  default       => sub {
      my $storage_class = $_[0]->event_storage_class;
      $_[0]->load($storage_class);
      return $storage_class->new;
  };

sub events {
    my $self = shift;
    return $self->event_storage->events;
}

sub results {
    my $self = shift;
    return $self->event_storage->results;
}


sub handle_event {
    my $self = shift;
    my $event = shift;

    $self->event_storage->events_push($event);
    $self->event_count( $self->event_count + 1 );
    $self->last_event($event);

    return;
}


sub handle_test_start {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->handle_event($event, $ec);

    croak "Saw a test_start, but testing has already started" if $self->test_start;
    croak "Saw a test_start, but testing has already ended"   if $self->test_end;

    $self->test_start($event);
    $self->pid_at_test_start($$) unless $self->pid_at_test_start;

    return;
}


sub handle_test_end {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->handle_event($event, $ec);

    croak "Saw a test_end, but testing has not yet started" if !$self->test_start;
    croak "Saw a test_end, but testing has already ended"   if $self->test_end;

    $self->test_end($event);

    return;
}


sub handle_abort {
    my $self = shift;
    my($event, $ec) = @_;

    $self->handle_event($event, $ec);

    $self->abort($event);

    return;
}


sub handle_subtest_start {
    my $self = shift;
    my($event, $ec) = @_;

    $self->handle_event($event, $ec);

    $self->subtest_start($event);

    return;
}


sub subtest_handler {
    my $self  = shift;
    my $event = shift;

    my $subhistory = $self->new(
        subtest      => $event,
        store_events => $self->store_events
    );

    return $subhistory;
}

sub handle_set_plan {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->handle_event($event, $ec);

    $self->plan($event);

    return;
}

sub has_events   { shift->event_count > 0 }

=head2 Results

=head3 results

    # The result of test #4.
    my $result = $history->results->[3];

Returns a list of all L<TB2::Result> objects seen in this test.

By default, no results are stored and this will throw an exception
unless C<< $history->store_events >> is true.

=cut

sub handle_result    {
    my $self = shift;
    my $result = shift;

    $self->last_result($result);
    $self->_update_result_statistics($result);
    $self->handle_event($result);

    return;
}


=head3 has_results

Returns true if we have stored results, false otherwise.

=cut

sub has_results { shift->result_count > 0 }


=head3 last_result

    my $result = $history->last_result;

Returns the last result seen.

=cut

has last_result => (
    is          => 'rw',
    isa         => class_type('TB2::Result::Base'),
);

=head2 Statistics

=cut

my @statistic_attributes = qw(
    pass_count
    fail_count
    literal_pass_count
    literal_fail_count
    todo_count
    skip_count
    result_count
    event_count
);

for my $name (@statistic_attributes) {
    has $name => (
        is => 'rw',
        isa => 'TB2::Positive_Int',
        default => 0,
    );
}

sub _update_result_statistics {
    my $self = shift;
    my $result = shift;

    $self->counter( $self->counter + 1 );
    $self->pass_count( $self->pass_count + 1 ) if $result->is_pass;
    $self->fail_count( $self->fail_count + 1 ) if $result->is_fail;
    $self->literal_pass_count( $self->literal_pass_count + 1 ) if $result->literal_pass;
    $self->literal_fail_count( $self->literal_fail_count + 1 ) if !$result->literal_pass;
    $self->todo_count( $self->todo_count + 1 ) if $result->is_todo;
    $self->skip_count( $self->skip_count + 1 ) if $result->is_skip;
    $self->result_count( $self->result_count + 1 );

    return;
}

=head3 event_count

A count of number of events that have been seen.

=head2 result_count

A count of the number of results which have been seen.

=head3 pass_count

A count of the number of passed tests seen.

That is any result for which C<is_pass> is true.

=head3 fail_count

A count of the number of failed tests seen.

That is any result for which C<is_fail> is true.

=head3 todo_count

A count of the number of TODO tests seen.

That is any result for which C<is_todo> is true.

=head3 skip_count

A count of the number of SKIP tests seen.

That is any result for which C<is_skip> is true.

=head3 can_succeed

Returns true if the test can still succeed.  That is, if nothing yet
has happened to cause it to fail and the plan can be fulfilled.

For example, running too few tests is ok, but if too many have been
run the test can never succeed.

In another example, if there is no plan yet issued, there is no plan
to violate.

=cut

sub can_succeed {
    my $self = shift;

    return 0 if $self->abort;

    # Testing is done, do the full check.
    return $self->test_was_successful if $self->done_testing;

    # A test failed.
    return 0 if $self->fail_count > 0;

    # If there's no plan yet, we can't have violated it.
    if( my $plan = $self->plan ) {
        if( my $expect = $plan->asserts_expected ) {
            # We ran more tests than the plan
            return 0 if $self->result_count > $expect;
        }
        elsif( $plan->skip ) {
            # We were supposed to skip everything, but we ran tests
            return 0 if $self->result_count;
        }
    }

    return 1;
}

=head3 test_was_successful

    my $test_passed = $history->test_was_successful;

This returns true if the test is considered successful, false otherwise.

The conditions for a test passing are...

* test_start, set_plan and test_end events were seen
* the plan is satisfied (the right number of Results were seen)
* no Results were seen out of order according to their test_number
* For every Result, is_fail() is false
* If asked at END time, the test process is exiting with 0

Note that this will not be true until C<test_end> has been seen.
Until then, use C<can_succeed>.

=cut

sub test_was_successful {
    my $self = shift;

    return 0 if $self->abort;

    # We're still testing
    return 0 if !$self->done_testing;

    my $plan = $self->plan;

    # No plan was seen
    if( !$plan ) {
        return 0;
    }

    # We failed a test
    if( $self->fail_count ) {
        return 0;
    }

    if( $plan->no_plan ) {
        # Didn't run any tests
        return 0 if !$self->result_count;
    }
    else {
        # Wrong number of tests
        return 0 if $self->result_count != $plan->asserts_expected;
    }

    # We're exiting with non-zero
    if($? and !$self->is_subtest) {
        return 0;
    }

    return 1;
}


=head3 in_test

    my $am_in_test = $history->in_test;

Returns true if we're in the middle of a test, that is a C<test_start>
event was seen but a C<test_end> event has not.

=cut

sub in_test {
    my $self = shift;

    return 0 if $self->abort;
    return $self->test_start && !$self->test_end;
}


=head3 done_testing

    my $testing_is_done = $history->done_testing;

Returns true if testing was started and it is done.  That is, both a
C<test_start> and a C<test_end> event has been seen.

=cut

sub done_testing {
    my $self = shift;

    return 0 if $self->abort;
    return $self->test_start && $self->test_end;
}


=head3 counter

    my $counter = $formatter->counter;
    $formatter->counter($counter);

Gets/sets the result counter.  This is usually the number of results
seen, but it is not guaranteed to be so.  It can be reset.

=cut

has counter => 
   is           => 'rw',
   isa          => 'TB2::Positive_Int',
   default      => 0
;


=head3 plan

    my $plan = $history->plan;

Returns the plan event for the current test, if any.

=cut

has plan =>
  is            => 'rw',
  does          => 'TB2::Event',
;


=head3 test_start

    my $test_start = $history->test_start;

Returns the C<test_start> event, if it has been seen.

=cut

has test_start =>
  is            => 'rw',
  does          => 'TB2::Event';


=head3 test_end

    my $test_end = $history->test_end;

Returns the C<test_end> event, if it has been seen.

=cut

has test_end =>
  is            => 'rw',
  does          => 'TB2::Event';


=head3 subtest

    my $subtest = $history->subtest;

Returns the current C<subtest> event for this object, if there is one.

=cut

has subtest =>
  is            => 'rw',
  does          => 'TB2::Event';

=head3 is_subtest

    my $is_subtest = $history->is_subtest;

Returns whether this $history represents a subtest.

=cut

sub is_subtest {
    my $self = shift;

    return $self->subtest ? 1 : 0;
}

=head3 subtest_depth

    my $depth = $history->subtest_depth;

Returns how deep in subtests the current test is.

The top level test has a depth of 0.  The first subtest is 1, the next
nested is 2 and so on.

=cut

sub subtest_depth {
    my $self = shift;

    return $self->subtest ? $self->subtest->depth : 0;
}    

=head3 subtest_start

    my $subtest_start = $history->subtest_start;

Returns the C<subtest_start> event, if it has been seen.

This is the event for the subtest I<about to start> or which I<has
just ended>.  It is not the event for the current subtest.

=cut

has subtest_start =>
  is            => 'rw',
  does          => 'TB2::Event';


=head3 abort

    my $abort = $history->abort;

Returns the last C<abort> event seen, if any.

=cut

has abort =>
  is            => 'rw',
  does          => 'TB2::Event';


=head3 pid_at_test_start

    my $process_id = $history->pid_at_test_start;

History records the $process_id at the time the test has started.

=cut

has pid_at_test_start =>
  is            => 'rw',
  isa           => 'TB2::Positive_NonZero_Int',
;


=head3 is_child_process

    my $is_child = $history->is_child_process;

Returns true if the current process is a child of the process which
started the test.

=cut

sub is_child_process {
    my $self = shift;

    my $pid_at_test_start = $self->pid_at_test_start;

    return 0 unless $pid_at_test_start;
    return 0 if $pid_at_test_start == $$;

    return 1;
}

=head2 HISTORY INTERACTION

=head3 consume

   $history->consume($old_history);

Appends $old_history results in to $history's results stack.

=cut

sub consume {
   my $self = shift;
   my $old_history = shift;

   croak 'consume() only takes History objects'
     unless eval { $old_history->isa("TB2::History") };

   croak 'Cannot consume() a History object which has store_events() off'
     unless eval { $old_history->store_events };

   $self->accept_event($_) for @{ $old_history->events };

   return;
};


no TB2::Mouse;
1;

