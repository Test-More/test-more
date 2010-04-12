package Test::Builder2::Result::Role::skip;

use Test::Builder2::Mouse::Role;

sub is_skip { 1 }

no Test::Builder2::Mouse::Role;

1;
