#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl'; }

{
    package My::Handler;

    use Test::Builder2::Mouse;
    with "Test::Builder2::EventHandler";
}

ok !My::Handler->accept_event(), "default accept_event does nothing";

done_testing();
