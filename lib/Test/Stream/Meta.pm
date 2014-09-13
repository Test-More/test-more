package Test::Stream::Meta;
use strict;
use warnings;

use Scalar::Util();

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/encoding modern todo stream/;
    Test::Stream::ArrayBase->cleanup;
}

use Test::Stream::Exporter qw/import export_to exports package_sub/;
exports qw{
    ENCODING MODERN TODO STREAM
    is_tester init_tester anoint
};
Test::Stream::Exporter->cleanup();

sub snapshot {
    my $self = shift;
    my $class = Scalar::Util::blessed($self);
    return bless [@$self], $class;
}

sub is_tester {
    my $pkg = shift;
    return unless package_sub($pkg, 'TB_TESTER_META');
    return $pkg->TB_TESTER_META;
}

sub init_tester {
    my $pkg = shift;
    return $pkg->TB_TESTER_META if package_sub($pkg, 'TB_TESTER_META');

    my $meta = bless ['legacy', 0, undef], __PACKAGE__;

    no strict 'refs';
    no warnings 'once';
    *{"$pkg\::TB_TESTER_META"} = sub { $meta };

    return $meta;
}

sub anoint {
    my ($target, $oil) = @_;
    $oil ||= caller;

    my $meta = init_tester($target);
    $meta->{anointed_by}->{$oil} = 1;
}

1;
