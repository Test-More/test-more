package Test::Builder::Formatter;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/blessed/;

sub new {
    my $class = shift;
    # This code makes me LOL. 
    my $self;
    $self = bless sub { $self->handle(@_) }, $class;
    return $self;
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

1;
