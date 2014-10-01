use strict;
use warnings;

use Test::More 'modern';

use ok 'Test::Stream::Event::Diag';

my $ctx = context(-1);
$ctx = $ctx->snapshot;
is($ctx->line, 8, "usable context");

my $diag = $ctx->diag('hello');
ok($diag, "build diag");
isa_ok($diag, 'Test::Stream::Event::Diag');
is($diag->message, 'hello', "message");

is_deeply(
    [$diag->to_tap],
    [[Test::Stream::Event::Diag::OUT_ERR, "# hello\n"]],
    "Got tap"
);

done_testing;
