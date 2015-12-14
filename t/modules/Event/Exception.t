use strict;
use warnings;
BEGIN { require "t/tools.pl" };
use Test2::Event::Exception;

my $exception = Test2::Event::Exception->new(
    trace => 'fake',
    error => "evil at lake_of_fire.t line 6\n",
);

ok($exception->causes_fail, "Exception events always cause failure");

require Test2::Hub::State;
my $state = Test2::Hub::State->new;
ok($state->is_passing, "passing");
ok(!$state->failed, "no failures");

$exception->update_state($state);

ok(!$state->is_passing, "not passing");
ok($state->failed, "failure added");

done_testing;
