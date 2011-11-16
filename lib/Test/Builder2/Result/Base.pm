package Test::Builder2::Result::Base;

use Test::Builder2::Mouse;
use Test::Builder2::Types;

with 'Test::Builder2::Event';

my $CLASS = __PACKAGE__;


=head1 NAME

Test::Builder2::Result::Base - Store the result of an assert

=head1 SYNOPSIS

    # Use TB2::Result as a factory, not TB2::Result::Base directly
    my $result = Test::Builder2::Result->new_result(%options);


=head1 DESCRIPTION

This represents the result of an assert, whether it passed or failed,
if it had any modifiers (directives), additional diagnostic
information, etc...

B<NOTE>: This object is in a very high state of flux.


=head1 Overloading

A Result object used as a boolean will be true if the assert passed,
false otherwise.

=cut

use overload(
    q{bool} => sub {
        my $self = shift;
        return !$self->is_fail;
    },
    fallback => 1,
);


=head1 METHODS

It has all the attributes and methods of a normal L<Test::Builder2::Event> plus...

=head2 Attributes

=head3 name

    my $name = $result->name;

The name of the assert.  For example...

    # The name is "addition"
    ok( 1 + 1, "addition" );

=cut

has name =>
  is    => 'rw',
  isa   => 'Str'
;


=head3 diag

    my $diag = $result->diag;

The structured diagnostics associated with this result.

Diagnostics are currently an array ref of key/value pairs.  Its an
array ref to keep the order.  This will probably change.

=cut

has diag =>
  is            => 'rw',
  isa           => 'ArrayRef',
  default       => sub { [] };


=head3 reason

    my $reason = $result->reason;

The reason for any modifiers.

=cut

has reason =>
  is    => 'rw',
  isa   => 'Str';


=head3 test_number

    my $number = $result->test_number;

The number associated with this test, if any.

B<NOTE> that most testing systems don't number their results.  And
even TAP tests are not required to do so.

=cut

has test_number =>
  is    => 'rw',
  isa   => 'Test::Builder2::Positive_NonZero_Int';


=head2 Methods

=head3 build_event_type

    my $type = $result->build_event_type;

Returns the type of this Event, for differenciation between other
Event objects.

The type is "result".

=cut

sub build_event_type { "result" }

sub keys_for_as_hash {
    my $self = shift;
    my $keys = $self->Test::Builder2::Event::keys_for_as_hash;
    push @$keys, "type";

    return $keys;
}


# Throw out any keys which have undef values.
# This makes it easier to construct objects without having to
# first check if the value is defined.
override BUILDARGS => sub {
    my $args = super;
    for (keys %$args) {
        delete $args->{$_} unless defined $args->{$_};
    }

    return $args;
};


=head3 literal_pass

Returns true if the assert passed without regard to any modifiers.

=cut

sub literal_pass {
    return 0;
}

=head3 is_unknown

Returns true if the result is unknown.  This usually indicates that
there should be a test here but none was written or it was skipped.

An example is a test skipped because it is not relevant to the
current environment (like a Windows specific test on a Unix machine).

=cut

sub is_unknown {
    return 0;
}


=head3 is_pass

Returns true if this test is considered a pass after consideration of
any modifiers.

For example, the result of a TODO test is always considered a pass no
matter what the actual result of the assert is.

=cut

sub is_pass {
    my $self = shift;
    return $self->literal_pass;
}


=head3 is_fail

The opposite of is_pass.

=cut

sub is_fail {
    my $self = shift;
    return !$self->literal_pass;
}


=head3 is_todo

Returns true if this result is TODO.

=cut

sub is_todo {
    return 0;
}


=head3 is_skip

Returns true if the assert was recording as existing but never run.

=cut

sub is_skip {
    return 0;
}


# XXX I don't think anything uses this.  It can probably go away.
my %TypeMap = (
    pass        => "is_pass",
    fail        => "is_fail",
    todo        => "is_todo",
    skip        => "is_skip",
    unknown     => "is_unknown",
);
sub types {
    my $self = shift;
    my %types;
    for my $type (sort { $a cmp $b } keys %TypeMap) {
        my $method = $TypeMap{$type};
        $types{$type} = $self->$method;
    }

    return \%types;
}

no Test::Builder2::Mouse;

1;


=head1 SEE ALSO

L<Test::Builder2::Result> Factory for creating results

L<Test::Builder2::History> Store the results

L<Test::Builder2::Formatter> Format results for display

=cut

1;
