package Test::Builder2::Result::Role::pass;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

sub literal_pass { 1 }

no Test::Builder2::Mouse::Role;

1;


=head1 NAME

Test::Builder2::Result::Role::pass - The assert passed

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert passed.

=cut
