#!perl -w

use strict;
use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder::NoOutput;


my $test = Test::Builder::NoOutput->create;
$test->plan( tests => 3 );

local $ENV{HARNESS_ACTIVE} = 0;

$test->ok(1, 'Foo');
is($test->read(), <<END);
TAP version 13
1..3
ok 1 - Foo
END

#line 30
$test->ok(0, 'Bar');
is($test->read(), <<END);
not ok 2 - Bar
#   Failed test 'Bar'
#   at $0 line 30.
END

$test->ok(1, 'Yar');
$test->ok(1, 'Car');
is($test->read(), <<END);
ok 3 - Yar
ok 4 - Car
END

#line 45
$test->ok(0, 'Sar');
is($test->read(), <<END);
not ok 5 - Sar
#   Failed test 'Sar'
#   at $0 line 45.
END

$test->_ending();
is($test->read(), <<END);
# 3 tests planned, but 5 ran.
# 2 tests of 5 failed.
END

done_testing(5);
