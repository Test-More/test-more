#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl'; }

{
    package My::Handler;

    use TB2::Mouse;
    with "TB2::EventHandler";
}

ok !My::Handler->handle_event(), "default handle_event does nothing";

done_testing();
