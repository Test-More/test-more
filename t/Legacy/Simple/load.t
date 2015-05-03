#!/usr/bin/perl
use Test::Stream::Shim;

# Because I broke "use Test::Simple", here's a test

use strict;
use warnings;

use Test::Simple;

print <<END;
1..1
ok 1 - use Test::Simple with no arguments
END
