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

=head2 Accessors

=head3 last_test_number

=cut

has last_test_number => (
    is          => 'rw',
    isa         => 'Int',
    default     => 0,
);


=head3 history

=cut

has history => (
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

    my $last_test = $self->last_test_number;
    $self->increment_test_number(scalar @_);

    return 0 unless $self->should_keep_history;

    splice @{$self->history}, $last_test, scalar @_, @_;

    return 1;
}


=head3 increment_test_number

=cut

sub increment_test_number {
    my $self      = shift;
    my $increment = @_ ? shift : 1;

    croak "increment_test_number() takes an integer, not '$increment'"
      unless $increment =~ /^[+-]?\d+$/;

    my $num = $self->last_test_number;
    return $self->last_test_number($num + $increment);
}


=head3 summary

=cut

sub summary {
    my $self = shift;

    return map { $_->{ok} } @{ $self->history };
}


=head3 is_passing

=cut

sub is_passing {
    my $self = shift;

    return (grep { !$_->{ok} } @{ $self->history }) ? 0 : 1;
}

1;

