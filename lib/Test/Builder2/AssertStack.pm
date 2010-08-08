package Test::Builder2::AssertStack;

use 5.008001;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

use Carp qw(confess);
sub sanity ($) { confess "Assert failed" unless $_[0] };


=head1 NAME

Test::Builder2::AssertStack - A stack of where asserts were called

=head1 SYNOPSIS

    use Test::Builder2::AssertStack;

    my $stack = Test::Builder2::AssertStack->new;

    $stack->push([caller]);
    my $caller = $stack->pop;
    my $asserts = $stack->asserts;

=head1 DESCRIPTION

Records what asserts have been called in the current user assert call
stack.  This is used to know at that point the user originally called
an assert, so diagnostics can report the file and line number from the
user's point of view despite being buried deep in stacks of asserts.

It can also let TB2 know when control is about to return to the user
from calling an assert so it can fire an end of assert action which
includes formatting and outputing the final result and diagnostics.

=head1 Methods

=head2 asserts

    my $asserts = $stack->asserts;

Returns an array ref of the asserts on the stack, in stack order.

=cut

has asserts =>
  is            => 'ro',
  isa           => 'ArrayRef[ArrayRef]',
  default       => sub { [] }
;

=head2 top

    my @top = $stack->top;

Returns the top of the stack as a list.

=cut

sub top {
    my $self = shift;

    my $asserts = $self->asserts;
    return @$asserts ? @{$asserts->[0]} : ();
}

=head2 at_top

    my $is_at_top = $stack->at_top;

Returns true if the stack contains just one assert.

=cut

sub at_top {
    my $self = shift;
    return @{$self->asserts} == 1;
}

=head2 in_assert

    my $is_in_assert = $stack->in_assert;

Returns true if there are any assertions on the stack

=cut

sub in_assert {
    my $self = shift;
    return @{$self->asserts} ? 1 : 0;
}

=head2 from_top

    my $message = $stack->from_top(@message);

Joins @message with empty string and returns it with " at $file line
$line" appended from the top of the stack.

Convenient for printing failure diagnostics.

=cut

sub from_top {
    my $self = shift;

    my @top = $self->top;
    sanity @top;

    return join "", @_, " at $top[1] line $top[2]";
}


=head2 push

    $stack->push(@asserts);

Push asserts onto the stack

=cut

sub push {
    my $self = shift;
    push @{$self->asserts}, @_;
}

=head2 pop

    my $assert = $stack->pop;

Pop an assert off the stack

=cut

sub pop {
    my $self = shift;

    my $asserts = $self->asserts;
    sanity @$asserts;

    return pop @$asserts;
}


no Test::Builder2::Mouse;

1;
