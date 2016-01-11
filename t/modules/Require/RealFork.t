use strict;
use warnings;

# Prevent Test2::Util from making 'CAN_REALLY_FORK' a constant
my $forks;
BEGIN {
    require Test2::Util;
    no warnings;
    *Test2::Util::CAN_REALLY_FORK = sub { $forks };
}

use Test2::Bundle::Extended -target => 'Test2::Require::RealFork';
BEGIN { require 't/tools.pl' }

{
    $forks = 0;
    is($CLASS->skip(), 'This test requires a perl capable of true forking.', "will skip");

    $forks = 1;
    is($CLASS->skip(), undef, "will not skip");
}

done_testing;
