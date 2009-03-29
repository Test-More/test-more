package Test::Builder2::ResultWrapper;

use strict;
use Mouse;


=head1 NAME

Test::Builder2::ResultWrapper - Wed a TB2::Result with a TB2::Output

=head1 SYNOPSIS

    use Test::Builder2::Result;

    my $wrapper = Test::Builder2::ResultWrapper->new(
        result => $result,
        output => $output
    );

=head1 DESCRIPTION

The ResultWrapper holds a Result and an Output object.  It acts like a
Result object, but when it gets destroyed it hands the Result to the
Output object for outputting.

This is primarily for use to be returned by Test::Builder2->ok() and
enables this sort of thing:

    my $result = Test::Builder2->ok($test, $name)
                               ->todo($reason);

This is a private class of Test::Builder2.  Do not use it outside of
the Test::Builder2 internals.

=head1 METHODS

=head3 new

  my $wrapper = Test::Builder2::ResultWrapper->new(
      result => $result,
      output => $output
  );

new() creates a new wrapper object that when destroyed displays the
result object.  The purpose of the wrapper is to allow you time to
query and add extra information to the result object before it is
displayed.  

Be careful about how you use it though because if you aren't careful
to ensure it's destroyed promptly you will end up with test results
displayed out of order.  The number of the test is determined before
the object is created so you need to ensure they are destroyed in
the correct order.

=cut

has result =>
  is  =>'ro',
  isa => 'Test::Builder2::Result'; 

has output =>
  is  => 'ro',
  isa => 'Test::Builder2::Output';


# Delegate all our method calls to the result object
{
    our $AUTOLOAD;
    sub AUTOLOAD {
        my $self = shift;

        my ( $class, $method_name ) = $AUTOLOAD =~ m/^ (.*) :: ([^:]+) $/x;

        unshift @_, $self->result;
        my $code = $self->result->can($method_name);

        if( !$code ) {
            my($caller, $file, $line) = caller;

            die sprintf qq[Can't locate object method "%s" via package "%s" at %s line %d.\n],
              $method_name, ref $self->result, $file, $line;
        }

        goto &$code;
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

# Delegate both isa() and can() so that we look like a subclass
sub isa {
    my $self = shift;
    return defined $self->result ? $self->result->isa(@_) : $self->SUPER::isa(@_);
}

sub can {
    my $self = shift;
    return defined $self->result ? $self->result->can(@_) : $self->SUPER::can(@_);
}

sub DESTROY
{
    my $self = shift;
    $self->output->result($self->result);
}

1;
