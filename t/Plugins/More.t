use strict;
use warnings;

use Test::Stream 'More';

imported qw{
    ok pass fail
    is isnt
    like unlike
    cmp_ok
    diag note
    plan skip_all done_testing
    BAIL_OUT
    todo skip
    can_ok isa_ok DOES_ok ref_ok
    imported not_imported
};

done_testing;
