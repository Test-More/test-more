use strict;
use warnings;

use Test2::API qw/context test2_stack/;

sub done_testing {
    my $ctx = context();

    die "Test Already ended!" if $ctx->hub->ended;
    $ctx->hub->finalize($ctx->trace, 1);
    $ctx->release;
}

sub ok($;$) {
    my ($bool, $name) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name);
    $ctx->release;
}

ok(1, "First");

my $filter = test2_stack->top->filter(sub {
    my ($hub, $event) = @_;
    $event->set_todo('here be dragons');
    $event->diag_todo(1);
    return $event;
});

ok(0, "Second");

test2_stack->top->unfilter($filter);

ok(1, "Third");

done_testing;
