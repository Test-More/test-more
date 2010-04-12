package Test::Builder2::Result::Role::pass;

use Test::Builder2::Mouse::Role;

sub literal_pass { 1 }

no Test::Builder2::Mouse::Role;

1;
