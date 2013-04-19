package TB2::threads::shared;

# Avoid loading threads::shared unless we absolutely have to.
# Avoids triggering once and future threading bugs

use strict;
use warnings;

use Config;

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(share shared_clone);

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

if( $Config{useithreads} && $INC{'threads.pm'} ) {
    require TB2::threads::shared::on;
    *share        = \&TB2::threads::shared::on::share;
    *shared_clone = \&TB2::threads::shared::on::shared_clone;
}
else {
    require TB2::threads::shared::off;
    *share        = \&TB2::threads::shared::off::share;
    *shared_clone = \&TB2::threads::shared::off::shared_clone;
}

1;

