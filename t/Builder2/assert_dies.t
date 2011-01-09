#!/usr/bin/perl

# Ensure that an assert which dies in the middle of itself doesn't
# leave the assert stack in a bad state.

# Whether a dying assert's result should be displayed is another
# matter.

use strict;
use warnings;

use Test::Simple tests => 2;

{
    package My::FatalAssert;

    use Test::Builder2::Module;
    our @EXPORT = qw(fatal will_die);

    install_test will_die => sub(;$) {
        return Builder->ok(1, @_);
    };

    # Die while there's a stack of asserts
    install_test fatal => sub(;$) {
        my $result = will_die(@_);
        die "An assert which dies";
        return $result;
    };
}

My::FatalAssert->import;

ok !eval {
    fatal("this will die");
    1;
};
ok 1, "this should be displayed";
