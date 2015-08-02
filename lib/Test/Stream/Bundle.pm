package Test::Stream::Bundle;
use strict;
use warnings;

use Carp qw/croak/;

use Test::Stream::Exporter;

default_export import => sub {
    my $class = shift;
    my @caller = caller;

    my $bundle = $class;
    $bundle =~ s/^Test::Stream::Bundle::/-/;

    require Test::Stream;
    Test::Stream->load(\@caller, $bundle, @_);
};

no Test::Stream::Exporter;

1;
