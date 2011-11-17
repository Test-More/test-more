#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl'; }

{
    package My::Watcher;

    use Test::Builder2::Mouse;
    with "Test::Builder2::EventWatcher";
}

ok !My::Watcher->handle_event(), "default handle_event does nothing";

done_testing();
