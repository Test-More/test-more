package Test::Builder2::Result::Role::todo;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

sub is_todo { 1 }
sub is_fail { 0 }

no Test::Builder2::Mouse::Role;

1;


=head1 NAME

Test::Builder2::Result::Role::todo - The assert is expected to fail

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert ran but is
expected to fail.

=cut
