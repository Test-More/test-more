use Test::Stream::Shim;
use strict;
use warnings;

use Test::More;

# Check that we aren't a sufficient version
use Test::SkipWithout 'Test::More' => '9000.001';

fail("should not see this");

done_testing;
