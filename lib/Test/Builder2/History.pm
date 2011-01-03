package Test::Builder2::History;

use Carp;
use Test::Builder2::Mouse;
use Test::Builder2::StackBuilder;

with 'Test::Builder2::Singleton',
     'Test::Builder2::EventWatcher',
     'Test::Builder2::CanTry';


=head1 NAME

Test::Builder2::History - Manage the history of test results

=head1 SYNOPSIS

    use Test::Builder2::History;

    # This is a shared singleton object
    my $history = Test::Builder2::History->singleton;
    my $result  = Test::Builder2::Result->new_result( pass => 1 );

    $history->accept_result( $result );
    $history->is_passing;

=head1 DESCRIPTION

This object stores and manages the history of test results.

=head1 METHODS

=head2 Constructors

=head3 singleton

    my $history = Test::Builder2::History->singleton;
    Test::Builder2::History->singleton($history);

Gets/sets the shared instance of the history object.

Test::Builder2::History is a singleton.  singleton() will return the same
object every time so all users can have a shared history.  If you want
your own history, call create() instead.

=head3 create

    my $history = Test::Builder2::History->create;

Creates a new, unique History object.

=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set


=head2 Events

=head3 events

A Test::Builder2::Stack of events, that include Result objects.

=head3 accept_event

Push an event to the events stack.

=head3 event_count

Get the count of events that are on the stack.

=cut

buildstack events => 'Any';
sub accept_event { shift->events_push(shift) }
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
sub accept_results   {   # for testing
    my $self = shift;
    $self->results_push($_) for @_;
}
sub result_count     { shift->results_count }

before results_push => sub {
   shift->events_push( shift );
};

=head2 accept_result

Add a result object to the end stack, 

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

=head3 is_passing

Returns true if we have not yet seen a failing test.

=cut

sub is_passing { shift->fail_count == 0 }


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

