use strict;
use warnings;

use Test::Stream::Context qw/context/;

sub plan {
    my $ctx = context();
    $ctx->plan(@_);
}

sub ok($;$) {
    my ($bool, $name) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name);
}

plan(2);

ok(1, "First");
ok(1, "Second");

1;
