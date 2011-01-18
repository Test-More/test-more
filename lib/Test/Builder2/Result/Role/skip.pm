package Test::Builder2::Result::Role::skip;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

sub is_skip { 1 }

no Test::Builder2::Mouse::Role;

1;


=head1 NAME

Test::Builder2::Result::Role::fail - The assert did not run

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert was not run, it
was skipped.

=cut
