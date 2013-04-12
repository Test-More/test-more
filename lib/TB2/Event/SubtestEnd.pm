package TB2::Event::SubtestEnd;

use TB2::Mouse;
use TB2::Types;
use TB2::threads::shared;

with 'TB2::Event', 'TB2::CanLoad';

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::SubtestEnd - End of a subtest event

=head1 DESCRIPTION

This is a L<TB2::Event> representing the end of a subtest.

Receiving this event indicates to the parent that the subtest has
ended.  All events from here out belong to the current test level.
Most event handlers will not have to be concerned about this.

Information about the subtest will be communicated back to the parent
handler via C<<$subtest_end->history>>

=head1 METHODS

It has all the methods and attributes of L<TB2::Event> with
the following differences and additions.

=head2 Attributes

=head3 history

The L<TB2::History> object from the subtest.

This can be used by event handlers to get information from the subtest.

Normally this will be filled in by L<TB2::TestState> during
posting.  A builder may put in an alternative history object.

=cut

has history =>
  is            => 'rw',
  isa           => 'TB2::History',
;


=head3 subtest_start

The matching L<TB2::Event::SubtestStart>.

Normally this will be filled in by L<TB2::TestState> during
posting.

=cut

has subtest_start =>
  is            => 'rw',
  isa           => 'TB2::Event::SubtestStart'
;


=head3 result

A Result summarizing the outcome of the subtest.

This will be created from the L<history> by default.

=cut

has result =>
  is            => 'rw',
  isa           => 'TB2::Result::Base',
  lazy          => 1,
  trigger       => sub { shared_clone($_[1]) },
  default       => sub {
      return shared_clone( $_[0]->_build_result );
  };

sub _build_result {
    my $self = shift;

    my $subtest_history = $self->history;

    my %result_args;

    # Inherit information from the subtest.
    if( my $subtest_start = $self->subtest_start ) {
        $result_args{name} = $subtest_start->name;

        # If the subtest was started in a todo context, the subtest result
        # will be todo.
        $result_args{directives} = $subtest_start->directives;
        $result_args{reason}     = $subtest_start->reason;
    }

    # Did the subtest pass?
    $result_args{pass} = $subtest_history->test_was_successful;

    # Inherit the context.
    for my $key (qw(file line)) {
        my $val = $self->$key();
        $result_args{$key} = $val if defined $val;
    }

    my $subtest_plan = $subtest_history->plan;
    if( $subtest_plan && $subtest_plan->skip ) {
        # If the subtest was a skip_all, make our result a skip.
        $result_args{skip} = 1;
        $result_args{reason} = $subtest_plan->skip_reason;
    }
    elsif( $subtest_history->result_count == 0 ) {
        # The subtest didn't run any tests
        my $name = $result_args{name};
        $result_args{name} = "No tests run in subtest";
        $result_args{name}.= qq[ "$name"] if defined $name;
    }

    $self->load("TB2::Result");
    return TB2::Result->new_result( %result_args );
}

=head3 build_event_type

The event type is C<subtest_end>.

=cut

sub build_event_type { "subtest_end" }

=head1 SEE ALSO

L<TB2::Event>  This does the Event role.

L<TB2::SubtestStart>  The cooresponding event which starts the subtest.

=cut

no TB2::Mouse;

1;
