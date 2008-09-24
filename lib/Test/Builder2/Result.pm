# A factory for test results.
package Test::Builder2::Result;

use Carp;
use Mouse;
my $CLASS = __PACKAGE__;

my %Result_Type_Map = ();

sub new {
    my($class, %args) = @_;

    $args{directive}  ||= '';

    my $result_class = $class->result_class_for(\%args);

    # Fall through defaults, because there's no other way to say
    # "if nobody else handled it".
    $result_class ||=
      $args{raw_passed}    ? "Test::Builder2::Result::Pass"   :
                             "Test::Builder2::Result::Fail"   ;

    return $result_class->new(%args);
}


sub register_result_class {
    my($class, $result_class, $check) = @_;

    $class->result_type_map->{$result_class} = $check;

    return;
}


sub result_class_for {
    my($class, $args) = @_;

    my $result_class;
    my $map = $class->result_type_map;
    while(($result_class, my($check)) = each %$map) {
        last if $check->($args);
    }

    return $result_class;
}


sub result_type_map {
    return \%Result_Type_Map;
}


package Test::Builder2::Result::Base;

use Mouse;

sub register_result {
    my($class, $check) = @_;

    Test::Builder2::Result->register_result_class($class, $check);

    return;
}

{
    my @keys = qw(
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

    sub as_hash {
        my $self = shift;
        return { 
            map  {
                my $val = $self->$_();
                defined $val ? ($_ => $val) : ()
            }
            @keys
        };
    }
}

# This is the interpreted result of the test.
# For example "not ok 1 # TODO" is true.
sub passed {
    my $self = shift;

    return $self->raw_passed;
}

# This is the raw result of the test with no further interpretation.
# For example "not ok 1 # TODO" is false.
has raw_passed => (
    is          => 'ro',
    isa         => 'Bool',
    required    => 1,
);

has test_number => (
    is          => 'ro',
    isa         => 'Int',
);

has description => (
    is          => 'ro',
    isa         => 'Str',
);

# Instead of "file" use the more generic "location"
has location    => (
    is          => 'ro',
    isa         => 'Str',
);

# Instead of "line number", the more generic "id".
has id          => (
    is          => 'ro',
    isa         => 'Str',
);

# skip, todo, etc...
has directive   => (
    is          => 'ro',
    isa         => 'Str',
);

# the reason associated with the directive
has reason      => (
    is          => 'ro',
    isa         => 'Str',
);

# a place to store YAML diagnostics associated with a test
has diagnostic  => (
    is          => 'rw',
    isa         => 'Test::Builder2::Diagnostic'
);

{
    package Test::Builder2::Result::Pass;

    use Mouse;

    extends 'Test::Builder2::Result::Base';

    sub passed { 1 }

    has '+raw_passed' => (
        default     => 1
    );

    # This is special cased.
    __PACKAGE__->register_result(sub {});
}


{
    package Test::Builder2::Result::Fail;

    use Mouse;

    extends 'Test::Builder2::Result::Base';

    sub passed { 0 }

    has '+raw_passed' => (
        default     => 0
    );

    # This is special cased.
    __PACKAGE__->register_result(sub {});
}


{
    package Test::Builder2::Result::Skip;

    use Mouse;

    # Skip tests always pass
    extends 'Test::Builder2::Result::Pass';

    has '+directive' => (
        default     => 'skip'
    );

    __PACKAGE__->register_result(sub {
        my $args = shift;
        return $args->{directive} eq 'skip';
    });
}


{
    package Test::Builder2::Result::Todo;

    use Mouse;

    # Todo tests always pass
    extends 'Test::Builder2::Result::Pass';

    has '+directive' => (
        default     => 'todo'
    );

    __PACKAGE__->register_result(sub {
        my $args = shift;
        return $args->{directive} eq 'todo';
    });
}

1;
