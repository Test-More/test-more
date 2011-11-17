package TB2::threads::shared::off;

use strict;

our $VERSION = '2.00_07';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

sub import {
    my $caller = caller;

    no strict;

    *{$caller . '::share'}        = sub { return $_[0] };
    *{$caller . '::shared_clone'} = sub { return $_[0] };
    *{$caller . '::lock'}         = sub { 0 };

    return;
}

1;
