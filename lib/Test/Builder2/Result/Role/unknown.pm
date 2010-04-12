package Test::Builder2::Result::Role::unknown;

use Test::Builder2::Mouse::Role;

sub is_unknown { 1 }

no Test::Builder2::Mouse::Role;

1;
