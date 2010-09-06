package Test::Builder2::threads::shared;

# Avoid loading threads::shared unless we absolutely have to.
# Avoids triggering once and future threading bugs

use strict;
use warnings;

use Config;

if( $] >= 5.008001 && $Config{useithreads} && $INC{'threads.pm'} ) {
    require Test::Builder2::threads::shared::on;
    our @ISA = qw(Test::Builder2::threads::shared::on);
}
else {
    require Test::Builder2::threads::shared::off;
    our @ISA = qw(Test::Builder2::threads::shared::off);
}

