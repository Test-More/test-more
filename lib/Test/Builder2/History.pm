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

=cut

sub new {
    my $class = shift;

    return $class->singleton || $class->singleton($class->create);
}


=head3 create

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

Gets/sets the History singleton.  Normally you should never have to
call this, but instead get the singleton through new().

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

The number of the next test to be run (starts at 1).

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

=cut

has should_keep_history => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 1,
);

=head2 Other Methods

=head3 add_test_history

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

=cut

sub summary {
    my $self = shift;

    return map { $_->{ok} } @{ $self->results };
}


=head3 is_passing

=cut

sub is_passing {
    my $self = shift;

    return (grep { !$_->{ok} } @{ $self->results }) ? 0 : 1;
}

1;

