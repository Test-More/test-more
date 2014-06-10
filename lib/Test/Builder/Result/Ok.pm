package Test::Builder::Result::Ok;
use strict;
use warnings;

use parent 'Test::Builder::Result';

Test::Builder::Result::_accessors(qw/bool real_bool name number todo skip/);

1;
