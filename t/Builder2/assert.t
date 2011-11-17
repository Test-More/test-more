#!/usr/bin/perl -w

use strict;

{
    package TB2::Assert;

    use Test::Builder2::Mouse;
    with "Test::Builder2::EventHandler";

    sub accept_result {
        my $self   = shift;
        my $result = shift;

        die "Test said to die" if $result->name =~ /\b die \b/x;

        return;
    };
}

Test::Builder2->default->test_state->add_late_watchers( TB2::Assert->new );

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

