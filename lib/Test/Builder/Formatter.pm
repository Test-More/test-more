package Test::Builder::Formatter;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/blessed/;

use Test::Builder::Util qw/new/;

sub handle {
    my $self = shift;
    my ($item) = @_;

    confess "Handler did not get a valid Test::Builder::Result object! ($item)"
        unless $item && blessed($item) && $item->isa('Test::Builder::Result');

    my $method = $item->type;

    # Not all formatters will handle all types.
    return 0 unless $self->can($method);

    $self->$method($item);

    return 1;
}

sub to_handler {
    my $self = shift;
    return sub { $self->handle(@_) };
}

1;
