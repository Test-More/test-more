package Test::Builder::Formatter;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/blessed/;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub handle {
    my $self = shift;
    my ($tb, $item) = @_;

    confess "Handler did not get a valid Test::Builder object! ($tb)"
        unless $tb && blessed($tb) && $tb->isa('Test::Builder');

    confess "Handler did not get a valid Test::Builder::Result object! ($item)"
        unless $item && blessed($item) && $item->isa('Test::Builder::Result');

    my $method = $item->type;

    # Not all formatters will handle all types.
    return 0 unless $self->can($method);

    $self->$method($tb, $item);

    return 1;
}

sub to_listener {
    my $self = shift;
    return sub { $self->handle(@_) };
}

1;
