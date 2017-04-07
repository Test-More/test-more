package Test2::Formatter::Stream::Serializer::Storable;
use strict;
use warnings;

use Test2::Util::HashBase;

use Storable qw/nstore_fd/;

sub send {
    my $self = shift;
    my ($io, $f, $num, $e) = @_;
    nstore_fd({facets => $f, number => $num}, $io);
}

1;
