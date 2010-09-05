package Test::Builder2::Result::Base;

use Test::Builder2::Mouse;
use Test::Builder2::Types;

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

=head2 Attributes

=head3 description

=head3 name

    my $name = $result->name;

The name of the assert.  For example...

    # The name is "addition"
    ok( 1 + 1, "addition" );

L<description> is the more generic alias to this method.

=head3 diagnostic

=head3 diag

    my $diag = $result->diag;

The structured diagnostics associated with this result.

Diagnostics are currently an array ref of key/value pairs.  Its an
array ref to keep the order.  This will probably change.

=head3 id

=head3 line

    my $line = $result->line;

The line number upon which this assert was run.

Because a single result can represent a stack of actual asserts, this
is generally the location of the first assert in the stack.

L<id> is a more generic alias.

=head3 location

=head3 file

    my $file = $result->file;

The file whre this assert was run.

Like L<line>, this represents the top of the assert stack.

=head3 reason

    my $reason = $result->reason;

The reason for any modifiers.

=head3 test_number

    my $number = $result->test_number;

The number associated with this test, if any.

B<NOTE> that most testing systems don't number their results.  And
even TAP tests are not required to do so.

=cut


my %attributes = (
  description   => { },
  diagnostic    => { isa => 'ArrayRef', },
  id            => { },
  location      => { },
  reason        => { },
  test_number   => { isa => 'Test::Builder2::Positive_Int', },
);
my @attributes = keys %attributes;

my %attr_defaults = (
    is  => 'rw',
    isa => 'Str',
);

for my $attr (keys %attributes) {
    my $has = $attributes{$attr};
    $has = { %attr_defaults, %$has };

    $has->{predicate} ||= "has_$attr";
    has $attr => %$has;
}

_alias($CLASS, name => \&description);
_alias($CLASS, diag => \&diagnostic);
_alias($CLASS, file => \&location);
_alias($CLASS, line => \&id);


sub get_attributes
{
    return \@attributes;
}


=head1 METHODS

=head3 as_hash

    my $hash = $self->as_hash;

Returns the attributes of a result as a hash reference.

Useful for quickly dumping the contents of a result.

=cut

sub as_hash {
    my $self = shift;
    return {
        map {
            my $val = $self->$_();
            defined $val ? ( $_ => $val ) : ()
        } @attributes, "type"
    };
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


# XXX Should be moved into a utilty class
sub _alias {
    my($class, $name, $code) = @_;

    no strict 'refs';
    *{$class . "::" . $name} = $code;
}

no Test::Builder2::Mouse;

1;


=head1 SEE ALSO

L<Test::Builder2::Result> Factory for creating results

L<Test::Builder2::History> Store the results

L<Test::Builder2::Formatter> Format results for display

=cut

1;
