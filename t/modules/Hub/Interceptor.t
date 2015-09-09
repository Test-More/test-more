use Test::Stream -V1, Compare => '*';

use Test::Stream::Hub::Interceptor;

my $one = Test::Stream::Hub::Interceptor->new();

isa_ok($one, 'Test::Stream::Hub::Interceptor', 'Test::Stream::Hub');

is(
    dies { $one->terminate(55) },
    object {
        prop 'blessed' => 'Test::Stream::Hub::Interceptor::Terminator';
        prop 'reftype' => 'SCALAR';
        prop 'this' => \'55';
    },
    "terminate throws an exception"
);

done_testing;
