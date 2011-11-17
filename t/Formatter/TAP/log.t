#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::Formatter::TAP;
use TB2::EventCoordinator;
use TB2::Events;


my $formatter;
sub setup {
    $formatter = TB2::Formatter::TAP->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
    $formatter->show_ending_commentary(0);
    isa_ok $formatter, "TB2::Formatter::TAP";

    my $ec = TB2::EventCoordinator->new(
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

    $ec->post_event( TB2::Event::Log->new(
        message => "stuff and things",
        level   => "warning"
    ));

    is last_error(), "# stuff and things\n";

    $ec->post_event( TB2::Event::Log->new(
        message => "uhhh yeah",
        level   => "alert"
    ));

    is last_error(), "# uhhh yeah\n";

    is last_output(), '';
}


note "notice and down"; {
    my $ec = setup;

    $ec->post_event( TB2::Event::Log->new(
        message => "this is a notice",
        level   => "notice"
    ));

    is last_output(), "# this is a notice\n";

    $ec->post_event( TB2::Event::Log->new(
        message => "and this is debugging",
        level   => "debug"
    ));

    is last_output(), "# and this is debugging\n";
    is last_error(), '';
}


note "multiline messages"; {
    my $ec = setup;

    $ec->post_event( TB2::Event::Log->new(
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

    $ec->post_event( TB2::Event::Log->new(
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


note "->show_log"; {
    my $ec = setup;
    ok $formatter->show_logs, "show_log defaults to on";

    note "...turn show_log off";
    $formatter->show_logs(0);

    $ec->post_event( TB2::Event::TestStart->new );

    $ec->post_event( TB2::Event::Log->new(
        message => "this should not show up",
        level   => "notice"
    ));

    $ec->post_event( TB2::Event::Log->new(
        message => "nor should this",
        level   => "warning"
    ));

    is last_output(), <<'', "show_log(0) prevented log messages";
TAP version 13

    is last_error(), '';
}


done_testing;
