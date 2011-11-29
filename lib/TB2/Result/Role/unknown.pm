package TB2::Result::Role::unknown;

use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


sub is_unknown { 1 }

no TB2::Mouse::Role;

1;


=head1 NAME

TB2::Result::Role::unknown - The result of the assert is not known

=head1 DESCRIPTION

Apply this role to a Result::Base object if the assert ran but the
result is not known.

The critical difference between this and a "skip" is in this case the
assert was run but for whatever reason no clear result came back.  The
utility of this status is up in the air.

=cut
