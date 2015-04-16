package Test::Builder::Loader;
use strict;
use warnings;

use Test::Stream::PackageUtil;

$Test::Builder::Level = 1;

*Test::Builder::AUTOLOAD = sub {
    $Test::Builder::Loader::AUTOLOAD =~ m/^(.*)::([^:]+)$/;
    my ($package, $sub) = ($1, $2);

    require Test::Builder;
    my $code = $package->can($sub);
    goto &$code if $code;

    my @caller = CORE::caller();
    die qq{Can't locate object method "$sub" via package "$package" at $caller[1] line $caller[2].\n};
} unless $INC{'Test/Builder.pm'};

1;
