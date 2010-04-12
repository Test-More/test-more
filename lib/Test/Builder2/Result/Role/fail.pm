package Test::Builder2::Result::Role::fail;

use Test::Builder2::Mouse::Role;

sub literal_pass { 0 }

no Test::Builder2::Mouse::Role;

1;
