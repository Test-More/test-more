package Test::Builder::TodoDiag;
use strict;
use warnings;

our $VERSION = '1.302014_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use base 'Test2::Event::Diag';

sub diagnostics { 0 }

1;
