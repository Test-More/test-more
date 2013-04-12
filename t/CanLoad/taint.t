#!/usr/bin/env perl -Tw

use strict;
use warnings;

BEGIN { require "./t/test.pl" }

my $Taint = $0;
$Taint =~ s{.}{}g;

note "Check taint is working"; {
    is $Taint, '';
    ok ! eval { eval $Taint };
    like $@, qr/Insecure dependency/;
}


note "Creating test class"; {
    package My::Thing;
    use TB2::Mouse;
    with "TB2::CanLoad";

    ::can_ok "My::Thing", "load";
}


note "Loading a tainted class"; {

    # A simple core module we're not likely to have loaded.
    my $module = "Text::Soundex";

    ok !$INC{"Text/Soundex.pm"}, "test module is not loaded";
    My::Thing->load("Text::Soundex".$Taint);
    ok $INC{"Text/Soundex.pm"}, "test module is not loaded";    
}


note "Has to look like a class"; {
    my $bogus = "::am::bogus";
    ok !eval { My::Thing->load($bogus); };
    like $@, qr/'::am::bogus' does not look like a module name/;
}

done_testing;
