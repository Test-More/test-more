package Test::Builder2::EventCoordinator::Default;

# This exists to allow builders to store the EventCoordinator singleton,
# but we can still swap it out behind the scenes.  Useful for
# Test::Builder2::Tester.

use Test::Builder2::Mouse;

require Test::Builder2::EventCoordinator;
has real_coordinator => 
  is            => 'rw',
  isa           => 'Test::Builder2::EventCoordinator',
  handles       => qr/^(?!create)\w+$/,
  default       => sub {
      return Test::Builder2::EventCoordinator->create;
  };
;

sub create {
    return $_[0]->new;
}

# Convince isa() that we act like an EventCoordinator
my $delegate = "Test::Builder2::EventCoordinator";
sub isa {
    my($self, $want) = @_;

    return $delegate->isa($want);
    return $self->SUPER::isa($want);
}

no Test::Builder2::Mouse;

1;

