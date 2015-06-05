use strict;
use warnings;
use Test::Stream::Context qw/context/;

sub plan {
    my $ctx = context();
    $ctx->plan(@_);
    $ctx->release;
}

sub ok($;$) {
    my ($bool, $name) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name);
    $ctx->release;
}

my $count = 100000;
plan($count);

ok(1, "an ok") for 1 .. $count;

1;
