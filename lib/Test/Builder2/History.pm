package Test::Builder2::History;

use Carp;

# Can't depend on Mouse, but want to see where we can go with a real OO system.
use Mouse;


=head1 NAME

Test::Builder2::History - Manage the history of test results

=head1 SYNOPSIS

    use Test::Builder2::History;

    # This is a shared singleton object
    my $history = Test::Builder2::History->new;

    $history->add_test_history( { ok => 1 } );
    $history->is_passing;

=head1 DESCRIPTION

This object stores and manages the history of test results.


=head1 METHODS

=head2 Constructors

=head3 new

    my $history = Test::Builder2::History->new;

Gets the instance of the history object.

Test::Builder2::History is a singleton.  new() will return the same
object every time so all users can have a shared history.  If you want
your own history, call create() instead.

=cut

sub new {
    my $class = shift;

    return $class->singleton || $class->singleton($class->create);
}


=head3 create

    my $history = Test::Builder2::History->create;

Creates a new, unique History object.

=cut

sub create {
    my $class = shift;
    return $class->SUPER::new(@_);
}


=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set

=head3 singleton

    my $history = Test::Builder2::History->singleton;
    Test::Builder2::History->singleton($history);

Gets/sets the History singleton.

Normally you should never have to call this, but instead get the
singleton through new().

=cut

# What?!  No class variables in Moose?!  Now I have to write the
# accessor by hand, bleh.
{
    my $singleton;
    sub singleton {
        my $class = shift;

        if( @_ ) {
            $singleton = shift;
        }

        return $singleton;
    }        
}

=head3 next_test_number

The number of the next test to be run.

Defaults to 1.

=cut

has next_test_number => (
    is          => 'rw',
    isa         => 'Int',
    default     => 1,
);


=head3 results

An array ref of the test history.  Remember that test 1 is index 0.

    # The result of test #4.
    my $result = $history->results->[3];

=cut

has results => (
    is          => 'rw',
    isa         => 'ArrayRef',
    default     => sub { [] },
);


=head3 should_keep_history

If set to false, no history will be recorded.  This is handy for very
long running tests that might consume a lot of memeory.

Defaults to true.

=cut

has should_keep_history => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 1,
);

=head2 Other Methods

=head3 add_test_history

    $history->add_test_history(@results);

Adds the @results to the existing test history at the point indicated
by next_test_number().  That's usually the end of the history, but if
next_test_number() is moved backwards it will overlay existing history.

next_test_number() will be incremented by the number of @results.

=cut


sub add_test_history {
    my $self    = shift;

    my $last_test = $self->next_test_number - 1;
    $self->increment_test_number(scalar @_);

    return 0 unless $self->should_keep_history;

    splice @{$self->results}, $last_test, scalar @_, @_;

    return 1;
}


=head3 increment_test_number

    $history->increment_test_number;
    $history->increment_test_number($by_how_much);

A convenience method for incrementing next_test_number().

If $by_how_much is not given it will increment by 1.

=cut

sub increment_test_number {
    my $self      = shift;
    my $increment = @_ ? shift : 1;

    croak "increment_test_number() takes an integer, not '$increment'"
      unless $increment =~ /^[+-]?\d+$/;

    my $num = $self->next_test_number;
    return $self->next_test_number($num + $increment);
}


=head3 summary

    my @summary = $history->results;

Returns a list of true/false values for each test result indicating if
it passed or failed.

=cut

sub summary {
    my $self = shift;

    return map { $_->{ok} } @{ $self->results };
}


=head3 is_passing

    my $is_passing = $history->is_passing;

Returns true if all the tests passed, false otherwise.

=cut

sub is_passing {
    my $self = shift;

    return (grep { !$_->{ok} } @{ $self->results }) ? 0 : 1;
}

1;

