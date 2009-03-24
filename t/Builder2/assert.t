#!/usr/bin/perl -w

use strict;


{
    package TB2::Assert::Builder;

    use base qw(Test::Builder2);

    sub test_end {
        my $self   = shift;
        my $result = shift;

        die if $result->description =~ /\b die \b/x;
    }
}


{
    package TB2::Assert;

    use Test::Builder2::Module;
    __PACKAGE__->builder(TB2::Assert::Builder->new);

    our @EXPORT = qw(assert ok);

    install_test( assert => sub {
        my($name) = @_;
        return $Builder->ok(1, $name);
    });

    install_test( ok => sub {
        my($test, $name) = @_;
        return $Builder->ok($test, $name);
    });
}

TB2::Assert->import( tests => 3 );
assert("pass");

ok( !eval {
    assert("die die die!");
}, "assert() dies on fail");
