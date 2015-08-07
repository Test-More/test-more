use strict;
use warnings;

use Test::Stream;

use Test::Stream::Hub;
use Test::Stream::DebugInfo;
use Test::Stream::Event::Plan;
use Test::Stream::Event::Diag;

my $hub = Test::Stream::Hub->new;
$hub->state->set_count(1);

my $dbg = Test::Stream::DebugInfo->new(
    frame => [__PACKAGE__, __FILE__, __LINE__],
);

my $ran = 0;
$hub->follow_up(sub {
    my ($d, $h) = @_;
    is($d, $dbg, "Got debug");
    is($h, $hub, "Got hub");
    ok(!$hub->state->ended, "Hub state has not ended yet");
    $ran++;
});

$hub->finalize($dbg);

is($ran, 1, "ran once");

is_deeply(
    $hub->state->ended,
    $dbg->frame,
    "Ended at the expected place."
);

eval { $hub->finalize($dbg) };

is($ran, 1, "ran once");

done_testing;
