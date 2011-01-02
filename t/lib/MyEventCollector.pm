# A basic EventWatcher that collects events

package MyEventCollector;

use Test::Builder2::Mouse;
with 'Test::Builder2::EventWatcher';

has results =>
  is        => 'rw',
  isa       => 'ArrayRef',
  default   => sub { [] }
;

has events =>
  is        => 'rw',
  isa       => 'ArrayRef',
  default   => sub { [] }
;

has coordinators =>
  is            => 'rw',
  isa           => 'ArrayRef',
  default       => sub { [] }
;

sub accept_result {
    my $self = shift;
    push @{ $self->results }, shift;
    push @{ $self->coordinators }, shift;
}

sub accept_event {
    my $self = shift;
    push @{ $self->events }, shift;
    push @{ $self->coordinators }, shift;
}

sub reset {
    my $self = shift;
    $self->results([]);
    $self->events([]);
    $self->coordinators([]);
}

1;
