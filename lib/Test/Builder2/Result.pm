package Test::Builder2::Result;

use strict;
use Mouse;


=head1 NAME

Test::Builder2::Result - Represent the result of a test

=head1 SYNOPSIS

    use Test::Builder2::Result;

    my $result = Test::Builder2::Result->new(%test_data);


=head1 DESCRIPTION

An object to store the result of a test.  Used both for historical
reasons and by Test::Builder2::Output objects to format the result.

Result objects are overloaded to return true or false in boolean
context to indicate if theypr passed or failed.

=head3 new

  my $result = Test::Builder2::Result->new(%test_data);

new() is a method which returns a $result based on your test data.

=cut


our @attributes = qw(
  description
  diagnostic
  directive
  id
  location
  raw_passed
  reason
  skip
  test_number
  todo
);

sub get_attributes
{
    return \@attributes;
}

{
    for my $key (@attributes) {
        my $accessor = "_${key}_accessor";
        has $accessor =>
          is            => 'rw',
          init_arg      => $key;

        # Mouse accessors can't be changed to return itself on set.
        my $code = sub {
            my $self = shift;
            if( @_ ) {
                $self->$accessor(@_);
                return $self;
            }
            return $self->$accessor;
        };

        # A public one which may be overriden.
        __PACKAGE__->_alias($key => $code) unless defined &{$key};
    }

    sub as_hash {
        my $self = shift;
        return {
            map {
                my $val = $self->$_();
                defined $val ? ( $_ => $val ) : ()
              } @attributes, "passed"
        };
    }

    use overload(
        q{bool} => sub {
            my $self = shift;
            return $self->passed;
        },
        q{""} => sub {
            my $self = shift;
            return $self->passed ? "ok" : "not ok";
        },
        fallback => 1,
    );
}


# This is the interpreted result of the test.
# For example "not ok 1 # TODO" is true.
sub passed {
    my $self = shift;

    return $self->todo || $self->raw_passed;
}

# Having tests modified by a directive is an unwieldy concept.
# POSIX tests make pass, fail, unimplemented and todo as first
# class test results.  This may make more sense and leave
# the whole directive business to Output::TAP.
sub directive {
    my $self = shift;

    return $self->_directive_accessor if $self->_directive_accessor;

    return 'todo' if $self->todo;
    return 'skip' if $self->skip;
    return '';
}

# Short aliases for these common things
__PACKAGE__->_alias(name => \&description);
__PACKAGE__->_alias(diag => \&diagnostic);


sub _alias {
    my($class, $name, $code) = @_;

    no strict 'refs';
    *{$class . "::" . $name} = $code;
}


1;
