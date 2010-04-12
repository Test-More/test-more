package Test::Builder2::Result::Role::todo;

use Test::Builder2::Mouse::Role;

sub is_todo { 1 }
sub is_fail { 0 }

no Test::Builder2::Mouse::Role;

1;
