use strict;
use warnings;

use ok 'Test::More';

{
    package Foo;
    use Test::More import => ['!explain'];
}

can_ok('Foo', qw/ok is context plan/);
ok(!Foo->can('explain'), "explain was not imported");

done_testing;
