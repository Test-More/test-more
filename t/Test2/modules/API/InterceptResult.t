use strict;
use warnings;

use Test2::Tools::Tiny qw/tests exception/;
use Test2::V0;
use Test2::API::InterceptResult;

*is_deeply = \&is;

die "FIXME!";

my $CLASS = 'Test2::API::InterceptResult';

ok($CLASS->can($_), "have sub '$_'") for qw/raw_events context state/;

tests init => sub {
    my $one = $CLASS->new();
    ok($one->isa($CLASS), "Got an instance");
    ok($one->squash_info, "squash_info is on by default");
    is_deeply($one->state, {}, "Got a sane default state (empty hashref)");
    is_deeply($one->raw_events, [], "Got a sane default raw_events (empty arrayref)");

    no warnings 'once';
    local *HUB::state = sub { {state => 'yes'} };

    my $two = $CLASS->new(hub => bless({}, 'HUB'));
    is_deeply($two->state, {state => 'yes'}, "Got state from hub");

    my $se = Test2::API::InterceptResult::Event->new(facet_data => {
        parent => {
            children => ['not a valid event'],
            state => { subtest => 'state' },
            hid => 'uhg',
        },
    });

    my $three = $CLASS->new(subtest_event => $se);
    is_deeply($three->state, { subtest => 'state' }, "Got state from subtest event");
    is_deeply($three->raw_events, ['not a valid event'], "Got raw events from subtest event");

    like(
        exception { $CLASS->new(subtest_event => Test2::API::InterceptResult::Event->new()) },
        qr/not a subtest event/,
        "subtest_event must be valid"
    );
};

my @CLEAR_CACHE_KEYS = qw/ events asserts subtests diags notes errors plans subtest_results /;

tests clear_cache => sub {
    my $one = $CLASS->new();
    $one->{$_} = 1 for @CLEAR_CACHE_KEYS;
    $one->clear_cache;
    ok(!$one->{$_}, "Cleared $_") for @CLEAR_CACHE_KEYS;
};

tests squash_info => sub {
    my $one = $CLASS->new();
    is($one->squash_info, 1, "Defaults to 1");

    my $two = $CLASS->new(squash_info => 0);
    is($two->squash_info, 0, "Can set at construction");

    $two->{$_} = 1 for @CLEAR_CACHE_KEYS;
    is($two->squash_info(1), 1, "Can change to on");
    ok(!$two->{$_}, "Cleared $_") for @CLEAR_CACHE_KEYS;

    $two->{$_} = 1 for @CLEAR_CACHE_KEYS;
    is($two->squash_info(1), 1, "no change");
    ok($two->{$_}, "Did not clear $_ without change") for @CLEAR_CACHE_KEYS;

    $two->{$_} = 1 for @CLEAR_CACHE_KEYS;
    is($two->squash_info(0), 0, "Can change to off");
    ok(!$two->{$_}, "Cleared $_") for @CLEAR_CACHE_KEYS;

    $two->{$_} = 1 for @CLEAR_CACHE_KEYS;
    is($two->squash_info(0), 0, "no change");
    ok($two->{$_}, "Did not clear $_ without change") for @CLEAR_CACHE_KEYS;
};

tests upgrade_events => sub {
    my $trace1 = {pid => $$, tid => 0, cid => 1, frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']};
    my $trace2 = {pid => $$, tid => 0, cid => 2, frame => ['Foo::Bar', 'Foo/Bar.pm', 43, 'note']};
    my $trace3 = {pid => $$, tid => 0, cid => 3, frame => ['Foo::Bar', 'Foo/Bar.pm', 44, 'subtest']};
    my $trace4 = {pid => $$, tid => 0, cid => 4, frame => ['Foo::Bar', 'Foo/Bar.pm', 45, 'diag']};

    require Test2::Event::V2;
    my @raw_facets = (
        # These 4 should merge, mix in 2 blessed events to make sure they are handled
        {
            trace => $trace1,
            info  => [{tag => 'DIAG', details => 'about to fail'}],
        },
        Test2::Event::V2->new(
            trace  => $trace1,
            assert => {pass => 0, details => 'fail'},
        ),
        Test2::Event::V2->new(
            trace => $trace1,
            info  => [{tag => 'DIAG', details => 'it failed'}],
        ),
        {
            trace => $trace1,
            info  => [{tag => 'DIAG', details => 'it failed part 2'}],
        },

        # Same trace, but should not merge as it has an assert
        {
            trace  => $trace1,
            assert => {pass => 0, details => 'fail again'},
            info   => [{tag => 'DIAG', details => 'it failed again'}],
        },

        # Stand alone note
        {
            trace => $trace2,
            info  => [{tag => 'NOTE', details => 'Take Note!'}],
        },

        # Subtest, note, assert, diag as 3 events, should be merged
        {
            trace => $trace3,
            info  => [{tag => 'NOTE', details => 'About to start subtest'}],
        },
        {
            trace  => $trace3,
            assert => {pass => 0, details => 'failed subtest'},
            parent => {details => 'foo', state => {}, children => [
                {
                    trace  => $trace1,
                    assert => {pass => 0, details => 'fail'},
                },
                {
                    trace => $trace1,
                    info  => [{tag => 'DIAG', details => 'it failed'}],
                },
            ]},
        },
        {
            trace => $trace3,
            info  => [{tag => 'DIAG', details => 'Subtest failed'}],
        },

        # Stand alone diag
        {
            trace => $trace4,
            info  => [{tag => 'DIAG', details => 'Diagnosis: Murder'}],
        },
    );

    my $one = $CLASS->new(squash_info => 1);

    is_deeply(
        $one->upgrade_events(\@raw_facets),
        [
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data => {
                    trace  => $trace1,
                    assert => {pass => 0, details => 'fail'},
                    info   => [
                        {tag => 'DIAG', details => 'about to fail'},
                        {tag => 'DIAG', details => 'it failed'},
                        {tag => 'DIAG', details => 'it failed part 2'},
                    ],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace  => $trace1,
                    assert => {pass => 0, details => 'fail again'},
                    info   => [{tag => 'DIAG', details => 'it failed again'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace2,
                    info  => [{tag => 'NOTE', details => 'Take Note!'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace  => $trace3,
                    assert => {pass => 0, details => 'failed subtest'},
                    parent => {
                        details  => 'foo',
                        state    => {},
                        children => [
                            Test2::API::InterceptResult::Event->new(
                                result_class => $CLASS,
                                facet_data   => {
                                    trace  => $trace1,
                                    assert => {pass => 0, details => 'fail'},
                                    info   => [{tag => 'DIAG', details => 'it failed'}],
                                }
                            ),
                        ],
                    },
                    info => [
                        {tag => 'NOTE', details => 'About to start subtest'},
                        {tag => 'DIAG', details => 'Subtest failed'},
                    ],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace4,
                    info  => [{tag => 'DIAG', details => 'Diagnosis: Murder'}],
                }
            ),
        ],
        "Upgraded and squashed events"
    );

    $one->squash_info(0);
    is_deeply(
        $one->upgrade_events(\@raw_facets),
        [
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace1,
                    info  => [{tag => 'DIAG', details => 'about to fail'}],
                }
            ),
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace  => $trace1,
                    assert => {pass => 0, details => 'fail'},
                }
            ),
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace1,
                    info  => [{tag => 'DIAG', details => 'it failed'}],
                }
            ),
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace1,
                    info  => [{tag => 'DIAG', details => 'it failed part 2'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace  => $trace1,
                    assert => {pass => 0, details => 'fail again'},
                    info   => [{tag => 'DIAG', details => 'it failed again'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace2,
                    info  => [{tag => 'NOTE', details => 'Take Note!'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace3,
                    info  => [{tag => 'NOTE', details => 'About to start subtest'}],
                }
            ),
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace  => $trace3,
                    assert => {pass => 0, details => 'failed subtest'},
                    parent => {
                        details  => 'foo',
                        state    => {},
                        children => [
                            Test2::API::InterceptResult::Event->new(
                                result_class => $CLASS,
                                facet_data   => {
                                    trace  => $trace1,
                                    assert => {pass => 0, details => 'fail'},
                                }
                            ),
                            Test2::API::InterceptResult::Event->new(
                                result_class => $CLASS,
                                facet_data   => {
                                    trace => $trace1,
                                    info  => [{tag => 'DIAG', details => 'it failed'}],
                                }
                            ),
                        ],
                    },
                }
            ),
            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace3,
                    info  => [{tag => 'DIAG', details => 'Subtest failed'}],
                }
            ),

            Test2::API::InterceptResult::Event->new(
                result_class => $CLASS,
                facet_data   => {
                    trace => $trace4,
                    info  => [{tag => 'DIAG', details => 'Diagnosis: Murder'}],
                }
            ),
        ],
        "Upgraded no squash"
    );

};

tests state => sub {
    my $one = $CLASS->new(
        state => {
            count        => 12,
            failed       => 5,
            follows_plan => 1,
            is_passing   => 0,
            nested       => 42,
            bailed_out   => 'foo',
            skip_reason  => 'xxx',
        },
    );

    is($one->assert_count, 12,    "got assert_count");
    is($one->failed_count, 5,     "got failed_count");
    is($one->follows_plan, 1,     "got follows_plan");
    is($one->is_passing,   0,     "got is_passing");
    is($one->nested,       42,    "got nested");
    is($one->bailed_out,   'foo', "got bailed_out");
    is($one->skipped,      'xxx', "got skipped");
};

tests mappings => sub {
    my @RAW_VERIETY = (
        {assert => {pass => 1, name => "pass"}},
        {assert => {pass => 0, name => "fail"}},
        {
            trace  => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']},
            assert => {pass  => 0, name => "fail"},
            amnesty => [{tag => 'TODO', details => 'it is todo'}],
            info => [{tag => 'DIAG', details => "this failed"}],
        },
        {
            trace  => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']},
            assert => {pass  => 1, name => "subtest"},
            parent => {
                state    => {count => 1, failed => 0, follows_plan => 1, is_passing => 1, nested => 1},
                children => [{assert => {pass => 1, name => "pass"}}],
            },
        },

        {
            trace => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']},
            info  => [
                {tag => 'DIAG', details => 'diag 1'},
                {tag => 'NOTE', details => 'note 1'},
            ],
        }, {
            trace => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok'],
            trace => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']},
            info  => [
                {tag => 'DIAG', details => 'diag 2'},
                {tag => 'NOTE', details => 'note 2'},
            ],
        },

        {
            trace  => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']},
            errors => [
                {tag => 'ERROR', details => 'error 1', fail => 0},
                {tag => 'ERROR', details => 'error 2', fail => 1},
            ],
        },

        {plan => {count => 1}},
        {plan => {count => 0, skip => 1, details => 'skipme'}},
    );

    my $one = $CLASS->new(raw_events => \@RAW_VERIETY);
    is(
        $one->flatten,
        [
            {
                causes_failure => 0,
                name           => undef,
                pass           => 1,
                trace_file     => undef,
                trace_line     => undef,
            },
            {
                causes_failure => 1,
                name           => undef,
                pass           => 0,
                trace_file     => undef,
                trace_line     => undef,
            },
            {
                DIAG           => ['this failed'],
                TODO           => ['it is todo'],
                causes_failure => 0,
                name           => undef,
                pass           => 0,
                trace_file     => 'Foo/Bar.pm',
                trace_line     => 42,
            },
            {
                causes_failure => 0,
                name           => undef,
                pass           => 1,
                trace_file     => 'Foo/Bar.pm',
                trace_line     => 42,

                subtest => {
                    count        => 1,
                    failed       => 0,
                    follows_plan => 1,
                    is_passing   => 1,
                    nested       => 1,
                },
            },
            {
                DIAG           => ['diag 1'],
                NOTE           => ['note 1'],
                causes_failure => 0,
                trace_file     => 'Foo/Bar.pm',
                trace_line     => 42,
            },
            {
                DIAG           => ['diag 2'],
                NOTE           => ['note 2'],
                causes_failure => 0,
                trace_file     => 'Foo/Bar.pm',
                trace_line     => 42,
            },
            {
                ERROR          => ['error 1', 'FATAL: error 2'],
                causes_failure => 1,
                trace_file     => 'Foo/Bar.pm',
                trace_line     => 42,
            },
            {
                causes_failure => 0,
                plan           => '1',
                trace_file     => undef,
                trace_line     => undef,
            },
            {
                causes_failure => 0,
                plan           => 'SKIP ALL: skipme',
                trace_file     => undef,
                trace_line     => undef,
            }
        ],
        "Got flattened",
    );
};

done_testing;
