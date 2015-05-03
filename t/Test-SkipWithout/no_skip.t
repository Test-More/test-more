use Test::Stream::Shim;
use strict;
use warnings;

use Test::More tests => 1;

# Make sure this is defined AFTER Test::More's end block
END {
    pass("Should See This");
};

use Test::SkipWithout 'Test::More' => '0.001';
