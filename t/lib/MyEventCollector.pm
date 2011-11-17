# A basic EventHandler that collects events

package MyEventCollector;

use TB2::Mouse;
with 'TB2::EventHandler';

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

sub handle_result {
    my $self = shift;
    push @{ $self->results }, shift;
    push @{ $self->coordinators }, shift;
}

sub handle_event {
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
