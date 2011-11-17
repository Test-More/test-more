package TB2::threads::shared;

# Avoid loading threads::shared unless we absolutely have to.
# Avoids triggering once and future threading bugs

use strict;
use warnings;

use Config;

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

if( $Config{useithreads} && $INC{'threads.pm'} ) {
    require TB2::threads::shared::on;
    our @ISA = qw(TB2::threads::shared::on);
}
else {
    require TB2::threads::shared::off;
    our @ISA = qw(TB2::threads::shared::off);
}

1;

