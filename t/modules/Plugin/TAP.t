use strict;
use warnings;

use Test::Stream::Sync;
use Test::Stream::Plugin::TAP;

my $init = Test::Stream::Sync->init_done;
eval { Test::Stream::Sync->set_formatter('xxx') };
my $error = $@;

require Test::Stream;
Test::Stream->load(
    [__PACKAGE__, __FILE__, __LINE__],
    'Core', 'Compare'
);

ok(!$init, "Sync was not yet initialized");
like($error, qr/Global Formatter already set/, "Formatter was already set");

done_testing();
