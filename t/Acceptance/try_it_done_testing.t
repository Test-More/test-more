use strict;
use warnings;

use Test::Stream::Context qw/context/;

sub done_testing {
    my $ctx = context();
    my $state = $ctx->hub->state;

    die "Test Already ended!" if $state->ended;
    $ctx->hub->finalize($ctx->debug);
}

sub ok($;$) {
    my ($bool, $name) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name);
}

ok(1, "First");
ok(1, "Second");

done_testing;

1;
