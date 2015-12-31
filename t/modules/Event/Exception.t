use strict;
use warnings;
BEGIN { require "t/tools.pl" };
use Test2::Event::Exception;

my $exception = Test2::Event::Exception->new(
    trace => 'fake',
    error => "evil at lake_of_fire.t line 6\n",
);

ok($exception->causes_fail, "Exception events always cause failure");

done_testing;
