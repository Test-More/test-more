package Test::Builder2;

use 5.006;
use Mouse;
use Carp qw(confess);

use Test::Builder2::Result;


=head1 NAME

Test::Builder2 - 2nd Generation test library builder

=head1 SYNOPSIS

=head1 DESCRIPTION

Just a stub at this point to get things off the ground.

=head2 METHODS

=head3 history

Contains the Test::Builder2::History object.

=cut

has history =>
  is            => 'rw',
  isa           => 'Test::Builder2::History',
  default       => sub {
      require Test::Builder2::History;
      Test::Builder2::History->new
  };

=head3 planned_tests

Number of tests planned.

=cut

has planned_tests =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

=head3 output

A Test::Builder2::Output object used to output results.

Defaults to Test::Builder2::Output::TAP.

=cut

has output =>
  is            => 'rw',
  isa           => 'Test::Builder2::Output',
  default       => sub {
      require Test::Builder2::Output::TAP;
      Test::Builder2::Output::TAP->new();
  };

=head3 top

=head3 top_stack

  my @top = $tb->top;
  my $top_stack = $tb->top_stack;

Stores the call level where the user's tests are written.  This is
mostly useful for printing out diagnostic messages with the file and
line number of the test.

It is stored as a stack, so you can wrap tests around tests.
C<$top_stack> is a list of array ref to the return value from
C<caller(EXPR)>.  C<<$tb->top>> is a convenience method which returns
C<<@{$top_stack->[0]}>>.

(Might change from the caller array to a hash)

=cut

has top_stack =>
  is            => 'ro',
  isa           => 'ArrayRef',
  default       => sub { [] };

sub top {
    my $self = shift;

    return @{$self->top_stack->[0]};
}


=head3 from_top

  my $msg = $tb->from_top(@msg);

A convenience method.  Attaches the traditional " at $file line $line"
to @msg using C<<$tb->top>>.  @msg is joined with no delimiter.

=cut

sub from_top {
    my $self = shift;

    my @top = $self->top;
    return join "", @_, " at $top[1] line $top[2]";
}

=head3 test_start

  $tb->test_start;

Called just before a user written test function begins, it allows
before-test actions as well as knowing what the "top" of the call
stack is for the purposes of reporting test file and line numbers.

=cut

sub test_start {
    my $self = shift;

    push @{$self->top_stack}, [caller(1)];

    return;
}

=head3 test_end

  $tb->test_end(@test_result);

Like C<test_start> but for just after a user written test finishes.
Allows end-of-test actions and pops the call stack.

The C<@test_result> may be used by the end-of-test action.

=cut

sub test_end {
    my $self = shift;
    my @result = @_;

    assert( pop @{$self->top_stack} );

    return;
}

=head3 plan

=cut

sub plan {
    my $self = shift;
    my %args = @_;

    $self->planned_tests( $args{tests} );

    $self->output->begin(%args);
}

=head3 ok

=cut

sub ok {
    my $self = shift;
    my $test = shift;
    my $name = @_ ? " - ".shift : '';

    my $num = $self->history->next_test_number;

    my $result = Test::Builder2::Result->new(
        test_number     => $num,
        description     => $name,
        raw_passed      => $test ? 1 : 0,
        passed          => $test ? 1 : 0,
    );
    $self->output->result($result);
    $self->history->add_test_history( $result );

    return $result;
}


=begin private

=head3 assert

    assert EXPRESSION;

A simple assert function.  Pass it an expression you expect to be true.

=end private

=cut

sub assert { confess "Assert failed" unless $_[0] };


1;
