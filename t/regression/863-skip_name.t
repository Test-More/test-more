use strict;
use warnings;

use Test::More;
use Test2::API qw/intercept/;
{
    package Foo;
    use Test2::Tools::Basic;
}


my $events = intercept {
    SKIP: {
        skip "skipme" => 1;
    }
};

use Data::Dumper;
print Dumper($events);
print Dumper($events->[0]->name);

ok(1);

done_testing;
