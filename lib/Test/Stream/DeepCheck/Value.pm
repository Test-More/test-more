package Test::Stream::DeepCheck::Value;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/val/],
);

use Test::Stream::DeepCheck qw/stringify deeptype/;
use Scalar::Util qw/looks_like_number/;
use Carp qw/croak/;

sub as_string { stringify(shift->{+VAL}) }

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;
    my $val = $self->{+VAL};

    my @summary = (stringify($got), stringify($val));
    my @diag = (
        "     \$got$path: $summary[0]",
        "\$expected$path: $summary[1]",
    );

    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        summary => \@summary,
        diag    => \@diag,
    );

    # True if both are undefined
    return $res->pass unless defined($got) || defined($val);

    # False if only 1 is defined, or only 1 is a ref
    return $res->fail if defined($val) xor defined($got);
    return $res->fail if ref($val)     xor ref($got);

    # Check if 2 regexps are the same
    return $res->test("$got" eq "$val") if deeptype($got) eq 'REGEXP' && deeptype($val) eq 'REGEXP';

    # Ref compare
    return $res->test($got == $val) if ref($val) && ref($got);

    # If they both look like numbers try a numeric compare, but also try string compare if numeric fails
    return $res->pass if looks_like_number($got) && looks_like_number($val) && $val == $got;

    # String compare as final fallback
    return $res->test("$got" eq "$val");
}

1;
