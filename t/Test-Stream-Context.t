use strict;
use warnings;

use Test::More;

use Test::Stream::Context qw/context/;

can_ok(__PACKAGE__, qw/context/);

my $frame;

# Ironically, this is a bad idea in production.
sub tool { context() };

ok(!eval { context(); return; }, "Fails in void context");
my $exception = "context() called, but return value is ignored at " . __FILE__ . ' line ' . (__LINE__ - 1);
like($@, qr/^\Q$exception\E/, "Got the exception" );

my $one = tool()->snapshot; $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];

my $two = tool(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];
ok($two->hub, "Got a hub");
isa_ok($two->hub, 'Test::Stream::Hub');
is_deeply($two->debug->frame, $frame, "Found place to report errors");

# Find existing instance
ok($one != $two, "2 different instances");
ok($two == tool(), "context() returns the same instance again");

# Test undef/collection
my $addr = "$two";
$two = undef;
$two = tool();
ok("$two" ne $addr, "Got a new context after old was undef'd");

# Hard Reset
Test::Stream::Context->clear;

my $three = tool(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::tool' ];
my $snap = $three->snapshot;
is_deeply($three, $snap, "Identical!");
ok($three != $snap, "Not the same instance (may share references)");

# Hard Reset
$one = undef;
$two = undef;
$three = undef;
Test::Stream::Context->clear;

my $ctx;
{ # Simulate an END block...
    local *END = sub { local *__ANON__ = 'END'; context() };
    $ctx = END(); $frame = [ __PACKAGE__, __FILE__, __LINE__, 'main::END' ];
}
is_deeply( $ctx->debug->frame, $frame, 'context is ok in an end block');

done_testing;

# This is necessary cause we have a root hub that will set the exit code to 255
# since no tests were run for it :-)
Test::Stream::Context->TOP_HUB->set_no_ending(1);
