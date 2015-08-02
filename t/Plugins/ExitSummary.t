use Test::Stream::Sync;
use Test::Stream 'LoadPlugin';

my $initial_count = Test::Stream::Sync->hooks;

load_plugin 'ExitSummary';
load_plugin 'ExitSummary';
load_plugin 'ExitSummary';

my $post_count = Test::Stream::Sync->hooks;

load_plugin 'More';

is($initial_count, 0, "no hooks initially");
is($post_count, 1, "Added the hook, but only once");

done_testing();
