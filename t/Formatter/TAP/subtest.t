#!/usr/bin/env perl -w

use strict;
use warnings;

use lib 't/lib';

BEGIN { require 't/test.pl' }

use Test::Builder2::Formatter::TAP;
use Test::Builder2::TestState;
use Test::Builder2::Events;

sub new_formatter {
    return Test::Builder2::Formatter::TAP->new(
        streamer_class => 'Test::Builder2::Streamer::Debug'
    );
}

sub new_state {
    return Test::Builder2::TestState->create(
        formatters => [new_formatter()]
    );
}


note "subtest"; {
    my $state = new_state();

    my @events = (
        Test::Builder2::Event::TestStart->new,
        Test::Builder2::Result->new_result( pass => 1 ),
        Test::Builder2::Event::SubtestStart->new,
          Test::Builder2::Event::TestStart->new,
          Test::Builder2::Result->new_result( pass => 1 ),
          Test::Builder2::Result->new_result( pass => 1 ),
          Test::Builder2::Event::SetPlan->new( asserts_expected => 2 ),
          Test::Builder2::Event::TestEnd->new,
        Test::Builder2::Event::SubtestEnd->new,
        Test::Builder2::Result->new_result( pass => 1 ),
        Test::Builder2::Event::SetPlan->new( asserts_expected => 3 ),
        Test::Builder2::Event::TestEnd->new,
    );

    $state->post_event($_) for @events;

    is $state->formatters->[0]->streamer->read('out'), <<'END';
TAP version 13
ok 1
    ok 1
    ok 2
    1..2
ok 2
ok 3
1..3
END

}


done_testing;
