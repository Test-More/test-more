package Test2::Formatter::Stream::Serializer::Dumper;
use strict;
use warnings;

use Test2::Util::HashBase;

use Data::Dumper;
BEGIN {
    if (Data::Dumper->can('Sparseseen')) {
        *USE_SPARSE_SEEN = sub () { 1 };
    }
    else {
        *USE_SPARSE_SEEN = sub () { 0 };
    }
}

sub send {
    my $self = shift;
    my ($io, $f, $num, $e) = @_;

    my $dumper = Data::Dumper->new([{facets => $f, number => $num}])->Indent(0)->Terse(1)->Useqq(1)->Sortkeys(1);
    $dumper->Sparseseen(1) if USE_SPARSE_SEEN;
    chomp(my $dump = $dumper->Dump);

    print $io "$dump\n";
}

1;
