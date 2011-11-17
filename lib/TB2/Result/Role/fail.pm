package TB2::Result::Role::fail;

use TB2::Mouse ();
use TB2::Mouse::Role;

sub literal_pass { 0 }

no TB2::Mouse::Role;

1;


=head1 NAME

TB2::Result::Role::fail - The assert failed

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert failed.

=cut
