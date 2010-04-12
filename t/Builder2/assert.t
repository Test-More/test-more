#!/usr/bin/perl -w

use strict;

{
    package TB2::Assert;

    require Test::Simple;
    use Test::Builder2::Mouse::Role;

    after assert_end => sub {
        my $self   = shift;
        my $result = shift;

        die "Test said to die" if $result->name =~ /\b die \b/x;
    };

    TB2::Assert->meta->apply(Test::Simple->builder);
}


use Test::Simple tests => 3;
ok(1, "pass");

ok( !eval {
    ok(1, "die die die!");
    1;
}, "assert() dies on fail");

