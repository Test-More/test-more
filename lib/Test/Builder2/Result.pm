# A factory for test results.
package Test::Builder2::Result;

use Carp;
my $CLASS = __PACKAGE__;


=head1 NAME

Test::Builder2::Result

=head1 SYNOPSIS

    use Test::Builder2::Result;

    my $result = Test::Builder2::Result->new(%test_data);


=head1 DESCRIPTION

=head3 new

  my $result = Test::Builder2::Result->new(%test_data);

new() is a method which returns a $result based on your test data.

=cut


sub new {
    my $class = shift;
    my %args = @_;
    $args{directive} ||= '';
    return bless \%args, $class;
}

{
    my @attributes = qw(
      description
      diagnostic
      directive
      id
      location
      passed
      raw_passed
      reason
      skip
      test_number
      todo
    );

    for my $key (@attributes) {
        my $code = sub {
            my $self = shift;
            if( @_ ) {
                $self->{$key} = shift;
                return $self;
            }
            return exists $self->{$key} ? $self->{$key} : $self->_defaults->{$key};
        };

        # A private one to remain pure
        __PACKAGE__->_alias("_${key}_accessor" => $code);

        # A public one which may be overriden.
        __PACKAGE__->_alias($key => $code) unless defined &{$key};
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
            return $self->passed;
        },
        q{""} => sub {
            my $self = shift;
            return $self->passed ? "ok" : "not ok";
        },
        fallback => 1,
    );
}


# Defaults for various accessors.
sub _defaults {
    return { todo => '', skip => '' }
}

# This is the interpreted result of the test.
# For example "not ok 1 # TODO" is true.
sub passed {
    my $self = shift;

    return $self->todo || $self->raw_passed;
}

sub directive {
    my $self = shift;

    return $self->_directive_accessor if($self->_directive_accessor);
    # think about POSIX tests PASS, FAIL, XFAIL, 
    # UNRESOLVED, UNSUPPORTED, UNTESTED
    return 'todo' if $self->todo;
    return 'skip' if $self->skip;
    return 'normal';
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
