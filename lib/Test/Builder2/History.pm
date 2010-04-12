package Test::Builder2::History;

use Carp;
use Test::Builder2::Mouse;

with 'Test::Builder2::Singleton';


=head1 NAME

Test::Builder2::History - Manage the history of test results

=head1 SYNOPSIS

    use Test::Builder2::History;

    # This is a shared singleton object
    my $history = Test::Builder2::History->singleton;
    my $result  = Test::Builder2::Result->new_result( pass => 1 );

    $history->add_test_history( $result );
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

Creates a new, unique History object with its own Counter.

=cut

sub BUILD {
    my $self = shift;
    $self->counter( Test::Builder2::Counter->create );

    return $self;
}

=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set

=head3 counter

A Test::Builder2::Counter object being used to store the count.

Defaults to the singleton.

=cut

has counter => (
    is      => 'rw',
    isa     => 'Test::Builder2::Counter',
    default => sub {
        require Test::Builder2::Counter;
        Test::Builder2::Counter->singleton;
    },
    handles => {
        current_count     => 'get',
    }
);

=head3 current_count

Returns the current number in the counter.

=head3 next_count

Returns the next number in the counter.

=cut

sub next_count {
    my $self = shift;
    return $self->current_count + 1;
}

=head3 results

An array ref of the test history expressed as Result objects.
Remember that test 1 is index 0.

    # The result of test #4.
    my $result = $history->results->[3];

=cut

has results => (
    is      => 'rw',
    isa     => 'ArrayRef[Test::Builder2::Result::Base]',
    default => sub { [] },
);

=head3 should_keep_history

If set to false, no history will be recorded.  This is handy for very
long running tests that might consume a lot of memeory.

Defaults to true.

=cut

has should_keep_history => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

=head2 Other Methods

=head3 add_test_history

    $history->add_test_history(@results);

Adds the @results to the existing test history at the point indicated
by C<counter>.  That's usually the end of the history, but if
C<counter> is moved backwards it will overlay existing history.

@results is a list of Result objects.

C<counter> will be incremented by the number of @results.

=cut

sub add_test_history {
    my $self = shift;

    croak "add_test_history() takes Result objects"
      if grep {
          local $@;
          !eval { $_->isa("Test::Builder2::Result::Base") }
      } @_;

    my $counter = $self->counter;
    my $last_test = $counter->get;
    $counter->increment( scalar @_ );

    return 0 unless $self->should_keep_history;

    _overlay($self->results, \@_, $last_test);

    return 1;
}


# splice() isn't implemented for (thread) shared arrays and its likely
# the History object will be shared in a threaded environment
sub _overlay {
    my( $orig, $overlay, $from ) = @_;

    my $to = $from + (@$overlay || 0) - 1;
    @{$orig}[$from..$to] = @$overlay;

    return;
}


=head3 summary

    my @summary = $history->results;

Returns a list of true/false values for each test result indicating if
it passed or failed.

=cut

sub summary {
    my $self = shift;

    return map { $_->is_fail ? 0 : 1 } @{ $self->results };
}

=head3 is_passing

    my $is_passing = $history->is_passing;

Returns true if all the tests passed, false otherwise.

=cut

sub is_passing {
    my $self = shift;

    return (grep { $_->is_fail } @{ $self->results }) ? 0 : 1;
}

1;

