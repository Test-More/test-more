use strict;
use warnings;
use Test::More;

open( my $fh, '>', '/dev/null' );

my $tb = Test::Builder->new;

ok(1);

done_testing;
