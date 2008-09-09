# A factory for test results.
package Test::Builder2::Result;

use Carp;
use Mouse;

sub new {
    my($class, %args) = @_;

    my $directive = $args{directive} || '';

    my $result_class = 
      $directive eq 'todo' ? "Test::Builder2::Result::Todo" :
      $directive eq 'skip' ? "Test::Builder2::Result::Skip" :
      $args{raw_passed}    ? "Test::Builder2::Result::Pass" :
                             "Test::Builder2::Result::Fail" ;

    return $result_class->new(%args);
}


package Test::Builder2::Result::Base;

use Mouse;

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
}


{
    package Test::Builder2::Result::Fail;

    use Mouse;

    extends 'Test::Builder2::Result::Base';

    sub passed { 0 }

    has '+raw_passed' => (
        default     => 0
    );
}


{
    package Test::Builder2::Result::Skip;

    use Mouse;

    # Skip tests always pass
    extends 'Test::Builder2::Result::Pass';

    has '+directive' => (
        default     => 'skip'
    );
}


{
    package Test::Builder2::Result::Todo;

    use Mouse;

    # Todo tests always pass
    extends 'Test::Builder2::Result::Pass';

    has '+directive' => (
        default     => 'todo'
    );
}

1;
