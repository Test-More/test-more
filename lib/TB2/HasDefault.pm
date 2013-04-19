package TB2::HasDefault;

use Carp;
use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::HasDefault - A role providing a shared default object

=head1 SYNOPSIS

  package TB2::Thing;

  use TB2::Mouse;
  with 'TB2::HasDefault';

  my $thing      = TB2::Thing->default;
  my $same_thing = TB2::Thing->default;

  my $new_thing  = TB2::Thing->create;

=head1 DESCRIPTION

B<FOR INTERNAL USE ONLY>

A role implementing default for Test::Builder2 classes.

Strictly speaking, this isn't a default because you can create more
instances.  Its more like giving the class a default.

=head1 METHODS

=head2 Constructors

=head3 default

    my $default = Class->default;
    Class->default($default);

Gets/sets the default object.

If there is no default one will be created by calling create().

=cut

# What?!  No class variables in Mouse?!  Now I have to write the
# accessor by hand, bleh.
{
    # This has to be shared else 5.12 and below segfault when a shared
    # TB2::TestState is put into it.  This is probably not viable in the
    # long term, but for now only TB2::TestState and TB2::Builder2
    # are using it.
    my %defaults :shared;

    sub default {
        my $class = shift;

        if(@_) {
            $defaults{$class} = shift;
        }
        elsif( !$defaults{$class} ) {
            $defaults{$class} = $class->make_default;
        }

        return $defaults{$class};
    }
}


=head3 new

Because it is not clear if new() will make a new object or return a
default (like Test::Builder does) new() will simply croak to force
the user to make the decision.

=cut

sub new {
    croak "Sorry, there is no new().  Use create() or default().";
}


=head3 create

  my $obj = Class->create(@args);

Creates a new, non-default object.

Currently calls Mouse's new method.

=cut

sub create {
    my $class = shift;

    # Mouse injects new(), we can't call SUPER.
    return $class->TB2::Mouse::Object::new(@_);
}


=head3 make_default

    my $default = $class->make_default;

Creates the object used as the default.

Defaults to calling C<< $class->create >>.  You can override.

One of the reasons to override is to ensure your default contains
other defaults.  Like a Builder will want to use the default
History and Formatter objects.

=cut

sub make_default {
    my $class = shift;
    return $class->create;
}

no TB2::Mouse::Role;

1;
