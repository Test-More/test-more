package Test2::AsyncSubtest::Formatter;
use strict;
use warnings;

our $VERSION = '0.000092';

use Test2::Util::HashBase qw/-wrap/;
use vars qw/$AUTOLOAD/;

sub write {
    my $self = shift;
    my ($e, $count, $f) = @_;

    $f = {%{ $f || $e->facet_data }};
    $f->{trace}->{nested} ||= 1;
    $f->{trace}->{buffered} ||= 1;

    $self->{+WRAP}->write($e, $count, $f);
}

sub DESTROY { }

sub AUTOLOAD {
    my $self = shift;

    my $meth = $AUTOLOAD;
    $meth =~ s/^.*:://g;

    $self->{+WRAP}->$meth(@_);
}

1;
