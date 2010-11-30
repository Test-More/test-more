# A basic EventWatcher that collects events

package MyEventCollector;

use Test::Builder2::Mouse;

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

sub accept_result {
    my $self = shift;
    push @{ $self->results }, @_;
}

sub accept_event {
    my $self = shift;
    push @{ $self->events }, @_;
}

sub reset {
    my $self = shift;
    $self->results([]);
    $self->events([]);
}

1;
