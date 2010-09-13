package Test::Builder2::HistoryStack;

use Carp;
use Test::Builder2::Mouse;
require Test::Builder2::Stack;

with 'Test::Builder2::Singleton';


=head1 NAME

Test::Builder2::HistoryStack - Manage the history of test results

=head1 SYNOPSIS

    use Test::Builder2::HistoryStack;

    # This is a shared singleton object
    my $history = Test::Builder2::HistoryStack->singleton;
    my $result  = Test::Builder2::Result->new_result( pass => 1 );

    $history->add_test_history( $result );
    $history->is_passing;

=head1 DESCRIPTION

This object stores and manages the history of test results.

=head1 METHODS

=head2 Constructors

=head3 singleton

    my $history = Test::Builder2::HistoryStack->singleton;
    Test::Builder2::HistoryStack->singleton($history);

Gets/sets the shared instance of the history object.

Test::Builder2::HistoryStack is a singleton.  singleton() will return the same
object every time so all users can have a shared history.  If you want
your own history, call create() instead.

=head3 create

    my $history = Test::Builder2::HistoryStack->create;

Creates a new, unique History object with its own Counter.

=head2 Accessors

Unless otherwise stated, these are all accessor methods of the form:

    my $value = $history->method;       # get
    $history->method($value);           # set


=head2 Results

=head3 results

A Test::Builder2::Stack of Result objects.

    # The result of test #4.
    my $result = $history->results->[3];

=cut

has _results => (
    is      => 'rw',
    isa     => 'Test::Builder2::Stack',
    lazy    => 1,
    default => sub { Test::Builder2::Stack->new( type => 'Test::Builder2::Result::Base' ) },
    handles => { add_test_history => 'push',
                 add_result       => 'push',
                 add_results      => 'push',
                 result_count     => 'count',
                 results          => 'items',
               },
);

=head2 add_test_history, add_result, and add_results

Add a result object to the end stack, 

=head2 result_count

Get the count of results stored in the stack.

=head3 has_results

Returns true if we have stored results, false otherwise.

=cut

sub has_results { shift->result_count > 0 }
































=head2 Statistics


=cut












no Test::Builder2::Mouse;
1;
__END__



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

no Test::Builder2::Mouse;
1;

