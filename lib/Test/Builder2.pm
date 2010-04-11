package Test::Builder2;

use 5.008001;
use Test::Builder2::Mouse;
use Test::Builder2::Types;
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

has history_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::History',
);

has history => (
  is            => 'rw',
  isa           => 'Test::Builder2::History',
  builder       => '_build_history',
  lazy          => 1,
);

sub _build_history {
    my $self = shift;
    $self->history_class->singleton;
}


=head3 planned_tests

Number of tests planned.

=cut

has planned_tests =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

=head3 formatter

A Test::Builder2::Formatter object used to formatter results.

Defaults to Test::Builder2::Formatter::TAP.

=cut

has formatter_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::Formatter::TAP',
);

has formatter => (
  is            => 'rw',
  isa           => 'Test::Builder2::Formatter',
  builder       => '_build_formatter',
  lazy          => 1,
);

sub _build_formatter {
    my $self = shift;
    $self->formatter_class->new;
}


=head3 top

=head3 top_stack

  my @top = $tb->top;
  my $top_stack = $tb->top_stack;

Stores the call level where the user's tests are written.  This is
mostly useful for printing out diagnostic messages with the file and
line number of the test.

It is stored as a stack, so you can wrap tests around tests.
C<$top_stack> is a list of array ref to the return value from
C<caller(EXPR)>.  C<< $tb->top >> is a convenience method which returns
C<< @{$top_stack->[0]} >>.

(Might change from the caller array to a hash)

=cut

has top_stack =>
  is            => 'ro',
  isa           => 'ArrayRef[ArrayRef]',
  default       => sub { [] };

sub top {
    my $self = shift;

    return @{$self->top_stack->[0]};
}


=head3 from_top

  my $msg = $tb->from_top(@msg);

A convenience method.  Attaches the traditional " at $file line $line"
to @msg using C<< $tb->top >>.  @msg is joined with no delimiter.

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

    $self->formatter->begin(%args);
}

=head3 ok

  my $result = $tb->ok( $test );
  my $result = $tb->ok( $test, $name );

Records the result of a $test.  $test is simple true for success,
false for failure.

$name is a description of the test.

Returns a Test::Builder2::Result object representing the test.

=cut

sub ok {
    my $self = shift;
    my $test = shift;
    my $name = shift;

    my $num = $self->history->counter->get + 1;

    my $result = Test::Builder2::Result->new(
        test_number     => $num,
        description     => $name,
        type            => $test ? 'pass' : 'fail',
    );

    $self->accept_result($result);

    $self->formatter->result($result);

    return $result;
}


=head3 accept_result

  $tb->accept_result( $result );

Records a test $result (a Test::Builder2::Result object) to C<< $tb->history >>.

This is a bare bones version of C<< ok() >>.

=cut

sub accept_result {
    my $self = shift;
    my $result = shift;

    $self->history->add_test_history( $result );

    return;
}


=head3 done_testing

  $tb->done_testing();

Inform the Builder that testing is complete.  This will allow the builder to
perform any end of testing checks and actions, such as outputting a plan, and
inform any other objects, such as the formatter.

=cut

sub done_testing {
    my $self = shift;

    $self->formatter->end;
}

=begin private

=head3 assert

    assert EXPRESSION;

A simple assert function.  Pass it an expression you expect to be true.

=end private

=cut

sub assert { confess "Assert failed" unless $_[0] };


1;
