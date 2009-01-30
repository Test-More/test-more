#!/usr/bin/perl -w

use strict;


{
    package TB2::Assert::Builder;

    use base qw(Test::Builder2);

    sub test_end {
        my $self   = shift;
        my $result = shift;

        die "Assert failed" unless $result;
    }
}


{
    package TB2::Assert;

    use Test::Builder2::Module;
    __PACKAGE__->builder(TB2::Assert::Builder->new);

    our @EXPORT = qw(assert);

    install_test( assert => sub {
        my $test = shift;
        return $Builder->ok($test);
    });
}

TB2::Assert->import( tests => 3 );
assert(1);

assert( !eval {
    assert(0);
});
