package Test::Builder2::Result::Role::unknown;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Role;

sub is_unknown { 1 }

no Test::Builder2::Mouse::Role;

1;


=head1 NAME

Test::Builder2::Result::Role::unknown - The result of the assert is not known

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert ran but the
result is not known.

The critical difference between this and a "skip" is in this case the
assert was run but for whatever reason no clear result came back.  The
utility of this status is up in the air.

=cut
