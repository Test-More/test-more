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

=cut

sub new {
    my( $class, %args ) = @_;

    $args{directive} ||= '';

    my $result_class = $class->result_class_for( \%args );

    # Fall through defaults, because there's no other way to say
    # "if nobody else handled it".
    $result_class ||=
      $args{raw_passed} ? "Test::Builder2::Result::Pass" :
                          "Test::Builder2::Result::Fail" ;

    return $result_class->new(%args);
}

=head3 register_result_class

    $class->register_result_class($result_class, \&when_to_use);

Tells the Result factory that it should use the $result_class when
&when_to_use returns true.

=cut

sub register_result_class {
    my( $class, $result_class, $check ) = @_;

    $class->_result_type_map->{$result_class} = $check;

    return;
}

=head3 result_class_for

    my $result_class = $class->result_class_for(\%args);

Returns the $result_class which should be used for the %args to new().

=cut

sub result_class_for {
    my( $class, $args ) = @_;

    my $result_class;
    my $map = $class->_result_type_map;
    while( ( $result_class, my($check) ) = each %$map ) {
        last if $check->($args);
    }

    return $result_class;
}

my %Result_Type_Map = ();

sub _result_type_map {
    return \%Result_Type_Map;
}

package Test::Builder2::Result::Base;

sub register_result {
    my( $class, $check ) = @_;

    Test::Builder2::Result->register_result_class( $class, $check );

    return;
}

sub new {
    my $class = shift;
    my %args = @_;
    return bless \%args, $class;
}

{
    my @attributes = qw(
      passed
      raw_passed
      test_number
      description
      location
      id
      directive
      reason
      diagnostic
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
}


# Defaults for various accessors.
sub _defaults {
    return {}
}

# This is the interpreted result of the test.
# For example "not ok 1 # TODO" is true.
sub passed {
    my $self = shift;

    # Default to using the raw passed value
    return $self->raw_passed if !@_ and defined $self->_passed_accessor;

    return $self->_passed_accessor(@_);
}

# Short aliases for these common things
__PACKAGE__->_alias(name => \&description);
__PACKAGE__->_alias(diag => \&diagnostic);


sub _alias {
    my($class, $name, $code) = @_;

    no strict 'refs';
    *{$class . "::" . $name} = $code;
}


{

    package Test::Builder2::Result::Pass;

    use base 'Test::Builder2::Result::Base';

    sub passed { 1 }

    sub raw_passed { 1 }

    # This is special cased.
    __PACKAGE__->register_result( sub { } );
}

{

    package Test::Builder2::Result::Fail;

    use base 'Test::Builder2::Result::Base';

    sub passed { 0 }

    sub raw_passed { 0 }

    # This is special cased.
    __PACKAGE__->register_result( sub { } );
}

{

    package Test::Builder2::Result::Skip;

    # Skip tests always pass
    use base 'Test::Builder2::Result::Pass';

    sub directive {
        return 'skip';
    }

    __PACKAGE__->register_result(
        sub {
            my $args = shift;
            return $args->{directive} eq 'skip';
        }
    );
}

{

    package Test::Builder2::Result::Todo;

    # Todo tests always pass
    use base 'Test::Builder2::Result::Pass';

    sub directive {
        return 'todo'
    }

    __PACKAGE__->_alias( raw_passed => __PACKAGE__->can("_raw_passed_accessor") );

    __PACKAGE__->register_result(sub {
        my $args = shift;
        return $args->{directive} eq 'todo';
    });
}

1;
