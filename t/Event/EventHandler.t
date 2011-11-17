#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl'; }

{
    package My::Watcher;

    use Test::Builder2::Mouse;
    with "Test::Builder2::EventHandler";
}

ok !My::Watcher->accept_event(), "default accept_event does nothing";

done_testing();
