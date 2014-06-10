package Test::Builder::Result::Bail;
use strict;
use warnings;

use parent 'Test::Builder::Result';

Test::Builder::Result::_accessors(qw/reason/);

1;
