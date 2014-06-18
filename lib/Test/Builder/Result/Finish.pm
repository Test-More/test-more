package Test::Builder::Result::Finish;
use strict;
use warnings;

use parent 'Test::Builder::Result';

Test::Builder::Result::_accessors(qw/tests_run tests_failed/);

1;
