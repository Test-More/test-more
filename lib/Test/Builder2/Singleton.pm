package Test::Builder2::Singleton;

# This is a role which implements a singleton

use Carp;
use Mouse;

use base 'Exporter';
our @EXPORT = qw(singleton create new);


# What?!  No class variables in Moose?!  Now I have to write the
# accessor by hand, bleh.
{
    my $singleton;

    sub singleton {
        my $class = shift;

        if(@_) {
            $singleton = shift;
        }
        elsif( !$singleton ) {
            $singleton = $class->create;
        }

        return $singleton;
    }
}


# Not clear if new() will make a new object or return a singleton.
# Force the user to know.
sub new {
    croak "Sorry, there is no new().  Use create() or singleton().";
}


sub create {
    my $class = shift;

    return $class->SUPER::new(@_);
}

1;
