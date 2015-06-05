use strict;
use warnings;

use Test::Stream;

use Test::Stream::Hub;
use Test::Stream::DebugInfo;
use Test::Stream::Event::Ok;

my $hub = Test::Stream::Hub->new();

my @events;
my @counts;
my $it = $hub->listen(sub {
    my ($h, $e, $count) = @_;
    is($h, $hub, "got hub");
    push @events => $e;
    push @counts => $count;
});

my $ok1 = Test::Stream::Event::Ok->new(
    pass => 1,
    name => 'foo',
    debug => Test::Stream::DebugInfo->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__ ],
    ),
);

my $ok2 = Test::Stream::Event::Ok->new(
    pass => 0,
    name => 'bar',
    debug => Test::Stream::DebugInfo->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__ ],
    ),
);

my $ok3 = Test::Stream::Event::Ok->new(
    pass => 1,
    name => 'baz',
    debug => Test::Stream::DebugInfo->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__ ],
    ),
);

$hub->send($ok1);
$hub->send($ok2);

$hub->unlisten($it);

$hub->send($ok3);

is_deeply(\@counts, [1, 2], "Got counts");
is_deeply(\@events, [$ok1, $ok2], "got events");

done_testing;
