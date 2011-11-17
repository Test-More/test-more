#!/usr/bin/perl -w

use strict;

{
    package TB2::Assert;

    use TB2::Mouse;
    with "TB2::EventHandler";

    sub handle_result {
        my $self   = shift;
        my $result = shift;

        die "Test said to die" if $result->name =~ /\b die \b/x;

        return;
    };
}

Test::Simple->builder->test_state->add_late_handlers( TB2::Assert->new );

use Test::Simple tests => 4;
ok(1, "pass");

ok(
    !eval {
        ok(1, "die die die!");
        1;
    },
    "assert() dies on fail"
);
ok $@ =~ /^Test said to die/, "right error message";

