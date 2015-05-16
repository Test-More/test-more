use strict;
use warnings;

use Test::More;

use Test::Stream::Hub;
use Test::Stream::DebugInfo;
use Test::Stream::Event::Ok;

my $hub = Test::Stream::Hub->new();

my @events;
my $it = $hub->munge(sub {
    my ($h, $e) = @_;
    is($h, $hub, "got hub");
    push @events => $e;
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

$hub->unmunge($it);

$hub->send($ok3);

is_deeply(\@events, [$ok1, $ok2], "got events");

$hub = Test::Stream::Hub->new();
@events = ();

$hub->munge(sub { $_[1] = undef });
$hub->listen(sub {
    my ($hub, $e) = @_;
    push @events => $e;
});

$hub->send($ok1);
$hub->send($ok2);
$hub->send($ok3);

ok(!@events, "Blocked events");

done_testing;
