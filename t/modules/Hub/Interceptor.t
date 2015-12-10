use strict;
use warnings;
use Test::Stream::Tester;

use Test::Stream::Hub::Interceptor;

my $one = Test::Stream::Hub::Interceptor->new();

ok($one->isa('Test::Stream::Hub'), "inheritence");;

my $e = exception { $one->terminate(55) };
ok($e->isa('Test::Stream::Hub::Interceptor::Terminator'), "exception type");
is($$e, 55, "Scalar reference value");

done_testing;
