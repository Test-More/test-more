#!/usr/bin/perl -w

use strict;

{
    package TB2::Assert::Builder;

    use Mouse;
    extends 'Test::Builder2';

    around 'ok' => sub {
        my $orig = shift;
        my $ret = $orig->(@_);

        die if $ret->description =~ /\bdie\b/x;

        return $ret;
    };
}


{
    package TB2::Assert;

    use Test::Builder2::Module;
    __PACKAGE__->builder(TB2::Assert::Builder->new);
    our @EXPORT = qw(assert);

    sub assert {
        my($test, $name) = @_;
        return $Builder->ok($test, $name);
    }
}

TB2::Assert->import( tests => 3 );
assert(1, "pass");

assert( !eval {
    assert(1, "die die die!");
}, "assert() dies on fail");
