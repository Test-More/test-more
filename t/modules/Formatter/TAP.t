use Test::Stream -V1, -SpecTester, '!UTF8', Compare => '*';
use PerlIO;

use Test::Stream::Formatter::TAP qw/OUT_STD OUT_ERR OUT_TODO/;

ok(my $one = Test::Stream::Formatter::TAP->new, "Created a new instance");
isa_ok($one, 'Test::Stream::Formatter::TAP');
my $handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
is($handles->[0], $handles->[2], "First and last handles are the same");
ok($handles->[0] != $handles->[1], "First and second handles are not the same");
my $layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };

if (${^UNICODE} & 2) { # 2 means STDIN
    ok($layers->{utf8}, "'S' is set in PERL_UNICODE, or in -C, honor it, utf8 should be on")
}
else {
    ok(!$layers->{utf8}, "Not utf8 by default")
}

$one->encoding('utf8');
is($one->encoding, 'utf8', "Got encoding");
$handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");

my $two = Test::Stream::Formatter::TAP->new(encoding => 'utf8');
$handles = $two->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");


{
    package My::Event;
    use Test::Stream::Formatter::TAP qw/OUT_STD OUT_ERR/;

    use base 'Test::Stream::Event';
    use Test::Stream::HashBase accessors => [qw/pass name diag note/];

    Test::Stream::Formatter::TAP->register_event(
        __PACKAGE__,
        sub {
            my $self = shift;
            my ($e, $num) = @_;
            return (
                [OUT_STD, "ok $num - " . $e->name . "\n"],
                [OUT_ERR, "# " . $e->name . " " . $e->diag . "\n"],
                [OUT_STD, "# " . $e->name . " " . $e->note . "\n"],
            );
        }
    );
}

my ($std, $err);
open( my $stdh, '>', \$std ) || die "Ooops";
open( my $errh, '>', \$err ) || die "Ooops";

my $it = Test::Stream::Formatter::TAP->new(
    handles => [$stdh, $errh, $stdh],
);

$it->write(
    My::Event->new(
        pass => 1,
        name => 'foo',
        diag => 'diag',
        note => 'note',
        debug => 'fake',
    ),
    55,
);

$it->write(
    My::Event->new(
        pass => 1,
        name => 'bar',
        diag => 'diag',
        note => 'note',
        debug => 'fake',
        nested => 1,
    ),
    1,
);

is($std, <<EOT, "Got expected TAP output to std");
ok 55 - foo
# foo note
    ok 1 - bar
    # bar note
EOT

is($err, <<EOT, "Got expected TAP output to err");
# foo diag
    # bar diag
EOT

$it = undef;
close($stdh);
close($errh);

($std, $err) = ("", "");
open( $stdh, '>', \$std ) || die "Ooops";
open( $errh, '>', \$err ) || die "Ooops";

$it = Test::Stream::Formatter::TAP->new(
    handles    => [$stdh, $errh, $stdh],
    no_diag    => 1,
    no_header  => 1,
    no_numbers => 1,
);

my $dbg = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
my $ok = Test::Stream::Event::Ok->new(pass => 1, name => 'xxx', debug => $dbg);
my $diag = Test::Stream::Event::Diag->new(msg => 'foo', debug => $dbg);
my $plan = Test::Stream::Event::Plan->new(max => 5,     debug => $dbg);
my $bail = Test::Stream::Event::Bail->new(reason => 'foo', nested => 1, debug => $dbg);

$it->write($_, 1) for $ok, $diag, $plan, $bail;

# This checks that the plan, the diag, and the bail are not rendered
is($std, "ok - xxx\n", "Only got the 'ok'");
is($err, "", "no diag");

describe events => sub {
    my $fmt = Test::Stream::Formatter::TAP->new;
    my $dbg;
    before_each dbg => sub {
        $dbg = Test::Stream::DebugInfo->new(
            frame => ['main_foo', 'foo.t', 42, 'main_foo::flubnarb'],
        );
    };

    my $set_todo;
    case deprecated_todo => sub {
        $set_todo = sub {
            my ($e, $msg) = @_;
            $e->debug->_set_todo($msg);
        };
    };
    case new_todo => sub {
        $set_todo = sub {
            my ($e, $msg) = @_;
            $e->set_todo($msg);
        };
    };

    tests bail => sub {
        my $bail = Test::Stream::Event::Bail->new(
            debug => $dbg,
            reason => 'evil',
        );

        is(
            [$fmt->event_tap($bail, 1)],
            [[OUT_STD, "Bail out!  evil\n" ]],
            "Got tap"
        );
    };

    tests diag => sub {
        my $diag = Test::Stream::Event::Diag->new(
            debug => $dbg,
            message => 'foo',
        );

        is(
            [$fmt->event_tap($diag, 1)],
            [[OUT_ERR, "# foo\n"]],
            "Got tap"
        );

        $diag->set_message("foo\n");
        is(
            [$fmt->event_tap($diag, 1)],
            [[OUT_ERR, "# foo\n"]],
            "Only 1 newline"
        );

        $diag->$set_todo('todo');
        is(
            [$fmt->event_tap($diag, 1)],
            [[OUT_TODO, "# foo\n"]],
            "Got tap in todo"
        );

        $diag->set_message("foo\nbar\nbaz");
        is(
            [$fmt->event_tap($diag, 1)],
            [[OUT_TODO, "# foo\n# bar\n# baz\n"]],
            "All lines have proper prefix"
        );

        $diag->$set_todo(undef);
        $diag->set_message("");
        is([$fmt->event_tap($diag)], [], "no tap with an empty message");

        $diag->set_message("\n");
        is([$fmt->event_tap($diag)], [[OUT_ERR, "\n"]], "newline on its own is unchanged");
    };

    tests exception => sub {
        my $exception = Test::Stream::Event::Exception->new(
            debug => $dbg,
            error => "evil at lake_of_fire.t line 6\n",
        );

        is(
            [$fmt->event_tap($exception, 1)],
            [[OUT_ERR, "evil at lake_of_fire.t line 6\n" ]],
            "Got tap"
        );
    };

    tests note => sub {
        my $note = Test::Stream::Event::Note->new(
            debug => $dbg,
            message => 'foo',
        );

        is(
            [$fmt->event_tap($note, 1)],
            [[OUT_STD, "# foo\n"]],
            "Got tap"
        );

        $note->set_message("foo\n");
        is(
            [$fmt->event_tap($note, 1)],
            [[OUT_STD, "# foo\n"]],
            "Only 1 newline"
        );

        $note->set_message("foo\nbar\nbaz");
        is(
            [$fmt->event_tap($note, 1)],
            [[OUT_STD, "# foo\n# bar\n# baz\n"]],
            "All lines have proper prefix"
        );

        $note->set_message("");
        is([$fmt->event_tap($note)], [], "no tap with an empty message");

        $note->set_message("\n");
        is([$fmt->event_tap($note)], [], "newline on its own is not shown");

        $note->set_message("\nxxx");
        is([$fmt->event_tap($note)], [[OUT_STD, "\n# xxx\n"]], "newline starting");
    };

    describe ok => sub {
        my $pass;
        case pass => sub { $pass = 1 };
        case fail => sub { $pass = 0 };

        tests name_and_number => sub {
            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, name => 'foo');
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 - foo\n"],
                ],
                "Got expected output"
            );
        };

        tests no_number => sub {
            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, name => 'foo');
            my @tap = $fmt->event_tap($ok, );
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " - foo\n"],
                ],
                "Got expected output"
            );
        };

        tests no_name => sub {
            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
                ],
                "Got expected output"
            );
        };

        # Deprecated
        tests skip_and_todo => sub {
            warns { $dbg->set_skip('b') };

            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
            $ok->$set_todo('a');
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO & SKIP a\n"],
                ],
                "Got expected output"
            );

            $ok->$set_todo("");

            @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO & SKIP\n"],
                ],
                "Got expected output"
            );
        };

        # Deprecated
        tests skip => sub {
            warns { $dbg->set_skip('b') };

            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # skip b\n"],
                ],
                "Got expected output"
            );

            warns { $dbg->set_skip("") };

            @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # skip\n"],
                ],
                "Got expected output"
            );
        };

        tests todo => sub {
            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
            $ok->$set_todo('b');
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO b\n"],
                ],
                "Got expected output"
            );

            $ok->$set_todo("");

            @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7 # TODO\n"],
                ],
                "Got expected output"
            );
        };

        tests empty_diag_array => sub {
            my $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass, diag => []);
            my @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
                ],
                "Got expected output (No diag)"
            );

            $ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => $pass);
            @tap = $fmt->event_tap($ok, 7);
            is(
                \@tap,
                [
                    [OUT_STD, ($pass ? 'ok' : 'not ok') . " 7\n"],
                ],
                "Got expected output (No diag)"
            );
        };

        tests diag => sub {
            my $ok = Test::Stream::Event::Ok->new(
                debug => $dbg,
                pass  => 0,
                name  => 'the_test',
                diag  => ['xxx'],
            );

            is(
                [$fmt->event_tap($ok, 4)],
                [
                    [OUT_STD, "not ok 4 - the_test\n"],
                    [OUT_ERR, "# xxx\n"],
                ],
                "Got tap for failing ok"
            );
        };
    };

    tests plan => sub {
        my $plan = Test::Stream::Event::Plan->new(
            debug => $dbg,
            max => 100,
        );

        is(
            [$fmt->event_tap($plan, 1)],
            [[OUT_STD, "1..100\n"]],
            "Got tap"
        );

        $plan->set_max(0);
        $plan->set_directive('SKIP');
        $plan->set_reason('foo');
        is(
            [$fmt->event_tap($plan, 1)],
            [[OUT_STD, "1..0 # SKIP foo\n"]],
            "Got tap for skip_all"
        );

        $plan = Test::Stream::Event::Plan->new(
            debug => $dbg,
            max => 0,
            directive => 'skip_all',
        );
        is(
            [$fmt->event_tap($plan)],
            [[OUT_STD, "1..0 # SKIP\n"]],
            "SKIP without reason"
        );

        $plan = Test::Stream::Event::Plan->new(
            debug => $dbg,
            max => 0,
            directive => 'no_plan',
        );
        is(
            [$fmt->event_tap($plan)],
            [],
            "NO PLAN"
        );
    };

    tests subtest => sub {
        my $st = 'Test::Stream::Event::Subtest';

        my $one = $st->new(
            debug     => $dbg,
            pass      => 1,
            buffered  => 1,
            name      => 'foo',
        );

        is(
            [$fmt->event_tap($one, 5)],
            [
                [OUT_STD, "ok 5 - foo {\n"],
                [OUT_STD, "}\n"],
            ],
            "Got Buffered TAP output"
        );

        $one->set_buffered(0);
        is(
            [$fmt->event_tap($one, 5)],
            [
                [OUT_STD, "ok 5 - foo\n"],
            ],
            "Got Unbuffered TAP output"
        );

        $one = $st->new(
            debug     => $dbg,
            pass      => 0,
            buffered  => 1,
            name      => 'bar',
            diag      => [ 'bar failed' ],
            subevents => [
                Test::Stream::Event::Ok->new(debug => $dbg, name => 'first',  pass => 1),
                Test::Stream::Event::Ok->new(debug => $dbg, name => 'second', pass => 0, diag => ["second failed"]),
                Test::Stream::Event::Ok->new(debug => $dbg, name => 'third',  pass => 1),

                Test::Stream::Event::Diag->new(debug => $dbg, message => 'blah blah'),

                Test::Stream::Event::Plan->new(debug => $dbg, max => 3),
            ],
        );

        {
            local $ENV{HARNESS_IS_VERBOSE};
            is(
                [$fmt->event_tap($one, 5)],
                [
                    [OUT_STD, "not ok 5 - bar {\n"],
                    [OUT_ERR, "# bar failed\n"],
                    [OUT_STD, "    ok 1 - first\n"],
                    [OUT_STD, "    not ok 2 - second\n"],
                    [OUT_ERR, "    # second failed\n"],
                    [OUT_STD, "    ok 3 - third\n"],
                    [OUT_ERR, "    # blah blah\n"],
                    [OUT_STD, "    1..3\n"],
                    [OUT_STD, "}\n"],
                ],
                "Got Buffered TAP output (non-verbose)"
            );
        }

        {
            local $ENV{HARNESS_IS_VERBOSE} = 1;
            is(
                [$fmt->event_tap($one, 5)],
                [
                    [OUT_STD, "not ok 5 - bar {\n"],
                    [OUT_ERR, "    # bar failed\n"],
                    [OUT_STD, "    ok 1 - first\n"],
                    [OUT_STD, "    not ok 2 - second\n"],
                    [OUT_ERR, "    # second failed\n"],
                    [OUT_STD, "    ok 3 - third\n"],
                    [OUT_ERR, "    # blah blah\n"],
                    [OUT_STD, "    1..3\n"],
                    [OUT_STD, "}\n"],
                ],
                "Got Buffered TAP output (verbose)"
            );
        }

        {
            local $ENV{HARNESS_IS_VERBOSE};
            $one->set_buffered(0);
            is(
                [$fmt->event_tap($one, 5)],
                [
                    # In unbuffered TAP the subevents are rendered outside of this.
                    [OUT_STD, "not ok 5 - bar\n"],
                    [OUT_ERR, "# bar failed\n"],
                ],
                "Got Unbuffered TAP output (non-verbose)"
            );
        }

        {
            local $ENV{HARNESS_IS_VERBOSE} = 1;
            $one->set_buffered(0);
            is(
                [$fmt->event_tap($one, 5)],
                [
                    # In unbuffered TAP the subevents are rendered outside of this.
                    [OUT_STD, "not ok 5 - bar\n"],
                    [OUT_ERR, "# bar failed\n"],
                ],
                "Got Unbuffered TAP output (verbose)"
            );
        }
    };
};

done_testing;
