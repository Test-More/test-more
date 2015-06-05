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

plan(0, skip_all => 'testing skip all');

die "Should not see this";

1;
