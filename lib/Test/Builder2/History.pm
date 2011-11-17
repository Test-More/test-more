package Test::Builder2::History;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::Types;
use Test::Builder2::StackBuilder;

with 'Test::Builder2::EventHandler',
     'Test::Builder2::CanTry';


=head1 NAME

Test::Builder2::History - Manage the history of test results

=head1 SYNOPSIS

    use Test::Builder2::History;

    my $history = Test::Builder2::History->new;
    my $ec = Test::Builder2::EventCoordinator->create(
        history => $history
    );

    my $pass  = Test::Builder2::Result->new_result( pass => 1 );
    $ec->post_event( $pass );
    $ec->history->can_succeed;   # true

    my $result  = Test::Builder2::Result->new_result( pass => 0 );
    $ec->post_event( $pass );
    $ec->history->can_succeed;   # false


=head1 DESCRIPTION

This object stores and manages the history of test results.

It is a L<Test::Builder2::EventHandler>.

=head1 METHODS

=head2 Constructors

=head3 new

    my $history = Test::Builder2::History->new;

Creates a new, unique History object.

=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set


=head2 Events

=head3 events

A Test::Builder2::Stack of events, that include Result objects.

=head3 event_count

Get the count of events that are on the stack.

=cut

buildstack events => 'Any';
sub accept_event {
    my $self = shift;
    my $event = shift;

    $self->events_push($event);

    return;
}


sub accept_test_start {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->accept_event($event, $ec);

    croak "Saw a test_start, but testing has already started" if $self->test_start;
    croak "Saw a test_start, but testing has already ended"   if $self->test_end;

    $self->test_start($event);
    $self->pid_at_test_start($$) unless $self->pid_at_test_start;

    return;
}


sub accept_test_end {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->accept_event($event, $ec);

    croak "Saw a test_end, but testing has not yet started" if !$self->test_start;
    croak "Saw a test_end, but testing has already ended"   if $self->test_end;

    $self->test_end($event);

    return;
}


sub accept_abort {
    my $self = shift;
    my($event, $ec) = @_;

    $self->accept_event($event, $ec);

    $self->abort($event);

    return;
}


sub accept_subtest_start {
    my $self = shift;
    my($event, $ec) = @_;

    $self->accept_event($event, $ec);

    $self->subtest_start($event);

    return;
}


sub subtest_handler {
    my $self  = shift;
    my $event = shift;

    my $subhistory = $self->new;
    $subhistory->subtest_depth( $event->depth );

    return $subhistory;
}

sub accept_set_plan {
    my $self  = shift;
    my($event, $ec) = @_;

    $self->accept_event($event, $ec);

    $self->plan($event);

    return;
}

sub event_count  { shift->events_count }
sub has_events   { shift->events_count > 0 }

=head2 Results

=head3 results

A Test::Builder2::Stack of Result objects.

    # The result of test #4.
    my $result = $history->results->[3];

=cut

buildstack results => 'Test::Builder2::Result::Base';
sub accept_result    { shift->results_push(shift) }
sub result_count     { shift->results_count }

before results_push => sub {
   shift->events_push( shift );
};


=head2 result_count

Get the count of results stored in the stack. 

NOTE: This could be diffrent from the number of tests that have been
seen, to get that count use test_count.

=head3 has_results

Returns true if we have stored results, false otherwise.

=cut

sub has_results { shift->result_count > 0 }


=head2 Statistics

=cut

# %statistic_mapping: 
# attribute_name => code_ref that defines how to increment attribute_name
#
# this is used both as a list of attributes to create as well as by 
# _update_statistics to increment the attribute. 
# code_ref will be handed a single result object that was to be added
# to the results stack.

my %statistic_mapping = (
    pass_count => sub{ shift->is_pass ? 1 : 0 },
    fail_count => sub{ shift->is_fail ? 1 : 0 },
    todo_count => sub{ shift->is_todo ? 1 : 0 },
    skip_count => sub{ shift->is_skip ? 1 : 0 },
    test_count => sub{ 1 },
);

has $_ => (
    is => 'rw',
    isa => 'Test::Builder2::Positive_Int',
    default => 0,
) for keys %statistic_mapping;

sub _update_statistics {
    my $self = shift;

    for my $attr ( keys %statistic_mapping ) {
        for my $result (@_) {
           $self->$attr( $self->$attr + $statistic_mapping{$attr}->($result) );
        }
    }
}


before results_push => sub{
    my $self = shift;

    for my $result (@_) {
        croak "results_push() takes Result objects"
          if !$self->try(sub { $result->isa('Test::Builder2::Result::Base') });
    }

    $self->_update_statistics(@_);
};

=head3 test_count

A count of the number of tests that have been added to results. This
value is not guaranteed to be the same as results_count if you have
altered the results_stack. This is a static counter of the number of
tests that have been seen, not the number of results stored.

=head3 pass_count

A count of the number of passed tests have been added to results.

=head3 fail_count

A count of the number of failed tests have been added to results.

=head3 todo_count

A count of the number of TODO tests have been added to results.

=head3 skip_count

A count of the number of SKIP tests have been added to results.

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
            return 0 if $self->test_count > $expect;
        }
        elsif( $plan->skip ) {
            # We were supposed to skip everything, but we ran tests
            return 0 if $self->test_count;
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
        return 0 if !$self->test_count;
    }
    else {
        # Wrong number of tests
        return 0 if $self->test_count != $plan->asserts_expected;
    }

    # We're exiting with non-zero
    if($?) {
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


=head3 plan

    my $plan = $history->plan;

Returns the plan event for the current stream, if any.

=cut

has plan =>
  is            => 'rw',
  does          => 'Test::Builder2::Event',
;


=head3 test_start

    my $test_start = $history->test_start;

Returns the C<test_start> event, if it has been seen.

=cut

has test_start =>
  is            => 'rw',
  does          => 'Test::Builder2::Event';


=head3 test_end

    my $test_end = $history->test_end;

Returns the C<test_end> event, if it has been seen.

=cut

has test_end =>
  is            => 'rw',
  does          => 'Test::Builder2::Event';


=head3 subtest_depth

    my $depth = $history->subtest_depth;

Returns how deep in subtests the current test is.

The top level test has a depth of 0.  The first subtest is 1, the next
nested is 2 and so on.

=cut

has subtest_depth =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_Int',
  default       => 0;


=head3 subtest_start

    my $subtest_start = $history->subtest_start;

Returns the C<subtest_start> event, if it has been seen.

This is the event for the subtest I<about to start> or which I<has
just ended>.  It is not the event for the current subtest.

=cut

has subtest_start =>
  is            => 'rw',
  does          => 'Test::Builder2::Event';


=head3 abort

    my $abort = $history->abort;

Returns the last C<abort> event seen, if any.

=cut

has abort =>
  is            => 'rw',
  does          => 'Test::Builder2::Event';


=head3 pid_at_test_start

    my $process_id = $history->pid_at_test_start;

History records the $process_id at the time the test has started.

=cut

has pid_at_test_start =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_NonZero_Int',
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
   croak 'consume() only takes History objects' 
      unless scalar(@_) 
          == scalar( grep{ local $@;
                           eval{$_->isa('Test::Builder2::History')} 
                         } @_ 
                   );
   $self->results_push( map{ @{ $_->results } } @_ );
};


no Test::Builder2::Mouse;
1;

