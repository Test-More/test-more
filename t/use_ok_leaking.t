#!/usr/bin/env perl -w

# use_ok was leaking Test::More's loaded pragmas [rt.cpan.org 67538]

no strict; # This is deliberate

use Test::More;

BEGIN { use_ok "Symbol"; }

$str = "hello"; # deliberately don't declare the variable
is $str, "hello";

done_testing;
