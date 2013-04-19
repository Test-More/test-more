package TB2::threads::shared::off;

use strict;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

sub share        { 0 }
sub shared_clone { return $_[0] };

1;
