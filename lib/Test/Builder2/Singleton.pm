package Test::Builder2::Singleton;

# This is a role which implements a singleton

use Carp;
use Test::Builder2::Mouse::Role;


=head1 NAME

Test::Builder2::Singleton - A singleton role for TB2

=head1 SYNOPSIS

  package TB2::Thing;

  use Test::Builder2::Mouse;
  with 'Test::Builder2::Singleton';

  my $thing      = TB2::Thing->singleton;
  my $same_thing = TB2::Thing->singleton;

  my $new_thing  = TB2::Thing->create;

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>

A role implementing singleton for Test::Builder2 classes.

=head1 METHODS

=head2 Constructors

=head3 singleton

    my $singleton = Class->singleton;
    Class->singleton($singleton);

Gets/sets the singleton object.

If there is no singleton one will be created by calling create().

=cut

# What?!  No class variables in Mouse?!  Now I have to write the
# accessor by hand, bleh.
{
    my %singletons;

    sub singleton {
        my $class = shift;

        if(@_) {
            $singletons{$class} = shift;
        }
        elsif( !$singletons{$class} ) {
            $singletons{$class} = $class->create;
        }

        return $singletons{$class};
    }
}


=head3 new

Because it is not clear if new() will make a new object or return a
singleton (like Test::Builder does) new() will simply croak to force
the user to make the decision.

=cut

sub new {
    croak "Sorry, there is no new().  Use create() or singleton().";
}


=head3 create

  my $obj = Class->create(@args);

Creates a new, non-singleton object.

Currently calls Mouse's new method.

=cut

sub create {
    my $class = shift;

    return $class->Test::Builder2::Mouse::Object::new(@_);
}

1;
