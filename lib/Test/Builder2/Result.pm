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
reasons and by Test::Builder2::Formatter objects to format the result.

Result objects are overloaded to return true or false in boolean
context to indicate if theypr passed or failed.

=head3 new

  my $result = Test::Builder2::Result->new(%test_data);

new() is a method which returns a $result based on your test data.

=cut


our @attributes = qw(
  type
  description
  diagnostic
  id
  location
  reason
  test_number
);


sub get_attributes
{
    return \@attributes;
}

{
    for my $key (@attributes) {

        my $accessor = "_${key}_accessor";

        # do a special case for type
        # to ensure a) it's filled in
        # b) it's within the list of expected
        #    values
        if($key eq "type")
        {
            has $accessor =>
              is            => 'rw',
              required      => 1,
              init_arg      => $key;
        }
        else
        {
            has $accessor =>
              is            => 'rw',
              init_arg      => $key;
        }

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

    sub valid_status {
        my $self = shift;
    }

    sub as_hash {
        my $self = shift;
        return {
            map {
                my $val = $self->$_();
                defined $val ? ( $_ => $val ) : ()
              } @attributes
        };
    }

    use overload(
        q{bool} => sub {
            my $self = shift;
            return !$self->is_fail;
        },
        q{""} => sub {
            my $self = shift;
            return $self->as_string;
        },
        fallback => 1,
    );
}


# Some aliases and convenience methods.
sub is_fail {
    my $self = shift;
    return $self->type eq 'fail';
}

sub is_todo {
    my $self = shift;
    return $self->type =~ qr/todo/x;
}

sub is_skip {
    my $self = shift;
    return $self->type =~ qr/skip/x;
}

sub todo {
    my $self = shift;
    my $reason = shift;

    $self->is_fail       ? $self->type("todo_fail") :
    $self->is_skip       ? $self->type("todo_skip") :
                           $self->type("todo_pass") ;
    $self->reason($reason);

    return $self;
}

sub skip {
    my $self = shift;
    my $reason = shift;

    $self->is_fail              ? $self->type("skip_fail") :
    $self->is_todo              ? $self->type("todo_skip") :
                                  $self->type("skip_pass") ;
    $self->reason($reason);

    return $self;
}

__PACKAGE__->_alias(name => \&description);
__PACKAGE__->_alias(diag => \&diagnostic);
__PACKAGE__->_alias(file => \&location);
__PACKAGE__->_alias(line => \&id);

sub as_string {
    my $self = shift;

    return $self->type;
}

sub _alias {
    my($class, $name, $code) = @_;

    no strict 'refs';
    *{$class . "::" . $name} = $code;
}


1;
