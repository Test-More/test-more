#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }

use TB2::Formatter::TAP;
use TB2::TestState;
use TB2::Events;

sub new_formatter {
    return TB2::Formatter::TAP->new(
        streamer_class => 'TB2::Streamer::Debug'
    );
}

sub new_state {
    return TB2::TestState->create(
        formatters => [new_formatter()]
    );
}


note "subtest"; {
    my $state = new_state();

    my @events = (
        TB2::Event::TestStart->new,
        TB2::Result->new_result( pass => 1 ),
        TB2::Event::SubtestStart->new,
          TB2::Event::TestStart->new,
          TB2::Result->new_result( pass => 1 ),
          TB2::Result->new_result( pass => 1 ),
          TB2::Event::SetPlan->new( asserts_expected => 2 ),
          TB2::Event::TestEnd->new,
        TB2::Event::SubtestEnd->new,
        TB2::Result->new_result( pass => 1 ),
        TB2::Event::SetPlan->new( asserts_expected => 3 ),
        TB2::Event::TestEnd->new,
    );

    $state->post_event($_) for @events;

    is $state->formatters->[0]->streamer->read('out'), <<'END';
TAP version 13
ok 1
    TAP version 13
    ok 1
    ok 2
    1..2
ok 2
ok 3
1..3
END

}


done_testing;
