package Test::Builder::Result::Finish;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Test::Builder::Util qw/accessors/;
accessors qw/tests_run tests_failed/;

1;
