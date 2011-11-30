#!/usr/bin/env perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

use TB2::EventCoordinator;
use TB2::Events;
use TB2::Streamer::Debug;

my $CLASS = 'TB2::Formatter::TAP::TB1';
use_ok $CLASS;

# Make the output consistent
local $ENV{HARNESS_ACTIVE} = 0;

my($streamer, $formatter);
sub new_formatter {
    $streamer = TB2::Streamer::Debug->new;
    $formatter = $CLASS->new(
        streamer => $streamer
    );

    return TB2::EventCoordinator->new(
        formatters => [$formatter]
    );
}


note "doesn't show the TAP version"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 10 ) );

    is $streamer->read_all, "1..10\n";
}


note "skip result"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( TB2::Result->new_result(
        pass    => 1,
        skip    => 1,
        reason  => "because",
        name    => 'foo',
    ));

    is $streamer->read('out'), <<'END';
1..1
ok 1 - foo # skip because
END

}


note "empty test name"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 1 ) );
    $ec->post_event( TB2::Result->new_result(
        pass    => 1,
        name    => '',
    ));

    is $streamer->read('out'), <<'END';
1..1
ok 1 - 
END

}


note "tests but no plan"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Result->new_result(
        pass    => 1,
    ));
    $ec->post_event( TB2::Event::TestEnd->new );

    is $streamer->read_all, <<'END';
ok 1
# Tests were run but no plan was declared and done_testing() was not seen.
END

}


note "extra tests"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 2 ) );
    $ec->post_event( TB2::Result->new_result(
        pass    => 1,
    ));
    $ec->post_event( TB2::Event::TestEnd->new );

    is $streamer->read_all, <<'END';
1..2
ok 1
# Looks like you planned 2 tests but ran 1.
END
}


note "failed tests"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 2 ) );
    $ec->post_event( TB2::Result->new_result(
        pass    => 1,
    ));
    $ec->post_event( TB2::Result->new_result(
        pass    => 0,
    ));
    $ec->post_event( TB2::Event::TestEnd->new );

    is $streamer->read_all, <<'END';
1..2
ok 1
not ok 2
#   Failed test.
# Looks like you failed 1 test of 2 run.
END

}


note "failed tests"; {
    my $ec = new_formatter;

    $ec->post_event( TB2::Event::TestStart->new );
    $ec->post_event( TB2::Event::SetPlan->new( asserts_expected => 2 ) );
    $ec->post_event( TB2::Event::TestEnd->new );

    is $streamer->read_all, <<'END';
1..2
# No tests run!
END

}


done_testing;
