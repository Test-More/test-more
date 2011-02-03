#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use Test::Builder2::Formatter::TAP;
use Test::Builder2::EventCoordinator;
use Test::Builder2::Events;


my $formatter;
sub setup {
    $formatter = Test::Builder2::Formatter::TAP->new(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "Test::Builder2::Formatter::TAP";

    my $ec = Test::Builder2::EventCoordinator->create(
        formatters => [$formatter],
    );

    return $ec;
}

sub last_output {
    $formatter->streamer->read('out');
}

sub last_error {
    $formatter->streamer->read('err');
}

note "warning and up"; {
    my $ec = setup;

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => "stuff and things",
        level   => "warning"
    ));

    is last_error(), "# stuff and things\n";

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => "uhhh yeah",
        level   => "alert"
    ));

    is last_error(), "# uhhh yeah\n";

    is last_output(), '';
}


note "notice and down"; {
    my $ec = setup;

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => "this is a notice",
        level   => "notice"
    ));

    is last_output(), "# this is a notice\n";

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => "and this is debugging",
        level   => "debug"
    ));

    is last_output(), "# and this is debugging\n";
    is last_error(), '';
}


note "multiline messages"; {
    my $ec = setup;

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => <<MSG,

basset hounds
    got
  long ears

MSG
        level   => "warning"
    ));

    is last_error(), <<MSG, "newlines and spacing preserved";
# 
# basset hounds
#     got
#   long ears
# 
MSG

    is last_output(), '';
}


note "escaping the message"; {
    my $ec = setup;

    $ec->post_event( Test::Builder2::Event::Log->new(
        message => <<MSG,
# foo ## stuff
#
MSG
        level   => "notice"
    ));

    is last_output(), <<MSG, "newlines and spacing preserved";
# # foo ## stuff
# #
MSG

    is last_error(), '';
}

done_testing;
