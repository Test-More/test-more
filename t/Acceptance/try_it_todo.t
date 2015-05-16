use strict;
use warnings;

use Test::Stream::Context qw/context TOP_HUB/;

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

my $todo = TOP_HUB->set_todo('here be dragons');
ok(0, "Second");
$todo = undef;

ok(1, "Third");

done_testing;

1;
