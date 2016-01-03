package Test2::Formatter::TB;
use strict;
use warnings;

use base 'Test2::Formatter::TAP';

sub _ok_event {
    my $self = shift;
    my ($e, $num) = @_;

    my @out = $self->SUPER::_ok_event(@_);

    splice(@out, 1, 1) if !$e->{pass} && $e->{_meta}->{'Test::Builder'};

    return @out;
}

1;
