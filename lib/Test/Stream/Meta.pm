package Test::Stream::Meta;
use strict;
use warnings;

use Scalar::Util();
use Test::Stream::Util qw/protect/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/encoding modern todo stream/;
    Test::Stream::ArrayBase->cleanup;
}

use Test::Stream::PackageUtil;

use Test::Stream::Exporter qw/import export_to default_exports/;
default_exports qw{
    ENCODING MODERN TODO STREAM
    is_tester init_tester
};
Test::Stream::Exporter->cleanup();

sub snapshot {
    my $self = shift;
    my $class = Scalar::Util::blessed($self);
    return bless [@$self], $class;
}

sub is_tester {
    my $pkg = shift;
    return unless package_sym($pkg, 'CODE', 'TB_TESTER_META');
    return $pkg->TB_TESTER_META;
}

sub init_tester {
    my $pkg = shift;
    return $pkg->TB_TESTER_META if package_sym($pkg, 'CODE', 'TB_TESTER_META');

    my $meta = bless ['legacy', 0, undef], __PACKAGE__;

    protect {
        eval "package $pkg; sub TB_TESTER_META { \$meta }; 1" || die $@;
    };

    return $meta;
}

1;
