#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

note "Setup a class for testing"; {
    package My::Thing;

    use TB2::Mouse;
    with "TB2::CanOpen";
}


note "open"; {
    my $obj = My::Thing->new;

    local($!, $@);

    my $file = "$$.tmp";
    my $msg = "Basset hounds got long ears\n";

    note "write"; {
        my $fh = $obj->open(">", $file);

        ok !$!;
        ok !$@;

        print $fh $msg;
    }

    note "read"; {
        my $fh = $obj->open("<", $file);

        ok !$!;
        ok !$@;

        is join("", <$fh>), $msg;
    }

    END { 1 while unlink $file }
}


note "open fails"; {
    my $obj = My::Thing->new;

    my $file = "i_do_not_exist.no";
    ok !eval { $obj->open("<", $file) };
    my $error = $@;

    open "<", $file;
    is $error, "$!\n", "exception throws $!";
}

done_testing;
