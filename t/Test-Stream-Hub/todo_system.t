use strict;
use warnings;
use Test::More;

use Test::Stream::Hub;
my $hub = Test::Stream::Hub->new();

{
    my $todo = $hub->set_todo('foo');
    ok($todo, "True");
    is($hub->get_todo, 'foo', "In todo");
}

is($hub->get_todo, undef, "Todo ended");

my $todo = $hub->set_todo('foo');
ok($todo, "True");
is($hub->get_todo, 'foo', "In todo");
$todo = undef;
is($hub->get_todo, undef, "Todo ended");

# Imitate Test::Builders todo:
our $TODOX;
{
    local $TODOX = $hub->set_todo('foo');
    ok($TODOX, "True");
    is($hub->get_todo, 'foo', "In todo");
}
is($hub->get_todo, undef, "Todo ended");

done_testing;
