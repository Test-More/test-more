package Test::Stream::Meta;
use strict;
use warnings;

use Scalar::Util();
use Test::Stream::Util qw/protect/;

use Test::Stream::ArrayBase(
    accessors => [qw/encoding modern todo stream/],
);

use Test::Stream::PackageUtil;

use Test::Stream::Exporter qw/import export_to default_exports/;
default_exports qw{ is_tester init_tester };
Test::Stream::Exporter->cleanup();

my %META;

sub snapshot {
    my $self = shift;
    my $class = Scalar::Util::blessed($self);
    return bless [@$self], $class;
}

sub is_tester {
    my $pkg = shift;
    return $META{$pkg};
}

sub init_tester {
    my $pkg = shift;
    $META{$pkg} ||= bless ['legacy', 0, undef], __PACKAGE__;
    return $META{$pkg};
}

1;
