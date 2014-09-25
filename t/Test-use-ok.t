use strict;
use warnings;

use Test::More 'modern';

use ok 'ok';

use Test::Tester2;

events_are (
    intercept {
        eval "use ok 'Something::Fake'; 1" || die $@;
    },
    check {
        event ok => {
            bool => 0,
            name => 'use Something::Fake;',
            diag => check {
                event diag => { message => qr/^\s*Failed test 'use Something::Fake;'/ };
            },
        };
    }
);

done_testing;
