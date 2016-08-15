use Test2::Bundle::Extended -target => 'Test2::Tools::Compare';
use Test2::Util::Table();
sub table { join "\n" => Test2::Util::Table::table(@_) }

{
    package My::Boolean;
    use overload bool => sub { ${$_[0]} };
}

{
    package My::String;
    use overload '""' => sub { "xxx" };
}

subtest simple => sub {
    imported_ok qw{
        match mismatch validator
        hash array bag object meta number string
        in_set not_in_set check_set
        item field call call_list call_hash prop check all_items all_keys all_vals all_values
        end filter_items
        T F D DF E DNE FDNE U
        event
        exact_ref
    };
};

subtest is => sub {
    my $events = intercept {
        def ok => (is(1, 1), '2 arg pass');

        def ok => (is('a', 'a', "simple pass", 'diag'), 'simple pass');
        def ok => (!is('a', 'b', "simple fail", 'diag'), 'simple fail');

        def ok => (is([{'a' => 1}], [{'a' => 1}], "complex pass", 'diag'), 'complex pass');
        def ok => (!is([{'a' => 2, 'b' => 3}], [{'a' => 1}], "complex fail", 'diag'), 'complex fail');

        def ok => (is(undef, undef), 'undef pass');
        def ok => (!is(0, undef), 'undef fail');

        my $true  = do { bless \(my $dummy = 1), "My::Boolean" };
        my $false = do { bless \(my $dummy = 0), "My::Boolean" };
        def ok => (is($true,  $true,  "true scalar ref is itself"),  "true scalar ref is itself");
        def ok => (is($false, $false, "false scalar ref is itself"), "false scalar ref is itself");

        my $x = \\"123";
        def ok => (is($x, \\"123", "Ref-Ref check 1"), "Ref-Ref check 1");

        $x = \[123];
        def ok => (is($x, \["123"], "Ref-Ref check 2"), "Ref-Ref check 2");

        def ok => (!is(\$x, \\["124"], "Ref-Ref check 3"), "Ref-Ref check 3");
    };

    do_def;

    like(
        $events,
        array {
            event Ok => sub {
                call pass => T();
                call name => undef;
            };

            event Ok => sub {
                call pass => T();
                call name => 'simple pass';
            };

            fail_events Ok => sub {
                call pass => F();
                call name => 'simple fail';
            };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK/],
                    rows   => [[qw/a eq b/]],
                );
            };
            event Diag => { message => 'diag' };

            event Ok => sub {
                call pass => T();
                call name => 'complex pass';
            };

            fail_events Ok => sub {
                call pass => F();
                call name => 'complex fail';
            };
            event Diag => sub {
                call message => table(
                    header => [qw/PATH GOT OP CHECK/],
                    rows   => [
                        [qw/[0]{a} 2 eq 1/],
                        [qw/[0]{b} 3 !exists/, '<DOES NOT EXIST>'],
                    ],
                );
            };
            event Diag => { message => 'diag' };

            event Ok => sub {
                call pass => T();
            };

            fail_events Ok => sub {
                call pass => F();
            };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK/],
                    rows   => [[qw/0 IS <UNDEF>/]],
                );
            };

            event Ok => sub {
                call pass => T();
                call name => "true scalar ref is itself";
            };

            event Ok => sub {
                call pass => T();
                call name => "false scalar ref is itself";
            };

            event Ok => sub {
                call pass => T();
                call name => "Ref-Ref check 1";
            };

            event Ok => sub {
                call pass => T();
                call name => "Ref-Ref check 2";
            };

            fail_events Ok => sub {
                call pass => F();
                call name => 'Ref-Ref check 3';
            };

            event Diag => { message => match qr/\$\*->\$\*->\[0\] \| 123 \| eq \| 124/ };

            end;
        },
        "Got expected events"
    );
};

subtest like => sub {
    my $events = intercept {
        def ok => (like(1, 1), '2 arg pass');

        def ok => (like('a', qr/a/, "simple pass", 'diag'), 'simple pass');
        def ok => (!like('b', qr/a/, "simple fail", 'diag'), 'simple fail');

        def ok => (like([{'a' => 1, 'b' => 2}, 'a'], [{'a' => 1}], "complex pass", 'diag'), 'complex pass');
        def ok => (!like([{'a' => 2, 'b' => 2}, 'a'], [{'a' => 1}], "complex fail", 'diag'), 'complex fail');

        my $str = bless {}, 'My::String';
        def ok => (like($str, qr/xxx/, 'overload pass'), "overload pass");
        def ok => (!like($str, qr/yyy/, 'overload fail'), "overload fail");

    };

    do_def;

    my $rx = "" . qr/a/;

    like(
        $events,
        array {
            event Ok => sub {
                call pass => T();
                call name => undef;
            };

            event Ok => sub {
                call pass => T();
                call name => 'simple pass';
            };

            fail_events Ok => sub {
                call pass => F();
                call name => 'simple fail';
            };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK/],
                    rows   => [[qw/b =~/, "$rx"]],
                );
            };
            event Diag => { message => 'diag' };

            event Ok => sub {
                call pass => T();
                call name => 'complex pass';
            };

            fail_events Ok => sub {
                call pass => F();
                call name => 'complex fail';
            };
            event Diag => sub {
                call message => table(
                    header => [qw/PATH GOT OP CHECK/],
                    rows   => [[qw/[0]{a} 2 eq 1/]],
                );
            };
            event Diag => { message => 'diag' };

            event Ok => sub {
                call pass => T();
                call name => 'overload pass';
            };

            $rx = qr/yyy/;
            fail_events Ok => sub {
                call pass => F();
                call name => 'overload fail';
            };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK/],
                    rows   => [[qw/xxx =~/, "$rx"]],
                );
            };

            end;
        },
        "Got expected events"
    );
};

subtest shortcuts => sub {
    is(1,            T(), "true");
    is('a',          T(), "true");
    is(' ',          T(), "true");
    is('0 but true', T(), "true");

    my @lines;
    my $events = intercept {
        is(0, T(), "not true");     push @lines => __LINE__;
        is('', T(), "not true");    push @lines => __LINE__;
        is(undef, T(), "not true"); push @lines => __LINE__;
    };
    like(
        $events,
        array {
            filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
            event Ok => sub { call pass => 0; prop line => $lines[0]; prop file => __FILE__; };
            event Ok => sub { call pass => 0; prop line => $lines[1]; prop file => __FILE__; };
            event Ok => sub { call pass => 0; prop line => $lines[2]; prop file => __FILE__; };
            end()
        },
        "T() fails for untrue",
    );

    is(0,     F(), "false");
    is('',    F(), "false");
    is(undef, F(), "false");

    $events = intercept {
        is(1,   F(), "not false");
        is('a', F(), "not false");
        is(' ', F(), "not false");
    };
    like(
        $events,
        array {
            filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
            event Ok => {pass => 0};
            event Ok => {pass => 0};
            event Ok => {pass => 0};
            end()
        },
        "F() fails for true",
    );

    is(undef, U(), "not defined");

    like(
        intercept { is(0, U(), "not defined") },
        array { event Ok => { pass => 0 } },
        "0 is defined"
    );

    is(0,            D(), "defined");
    is(1,            D(), "defined");
    is('',           D(), "defined");
    is(' ',          D(), "defined");
    is('0 but true', D(), "defined");

    like(
        intercept { is(undef, D(), "not defined") },
        array { event Ok => { pass => 0 } },
        "undef is not defined"
    );

    is(0,            DF(), "defined but false");
    is('',           DF(), "defined but false");

    like(
        intercept {
          is(undef,        DF());
          is(1,            DF());
          is(' ',          DF());
          is('0 but true', DF());
        },
        array {
          filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
          event Ok => { pass => 0 };
          event Ok => { pass => 0 };
          event Ok => { pass => 0 };
          event Ok => { pass => 0 };
        },
        "got fail for DF"
    );

    is([undef], [E()],   "does exist");
    is([],      [DNE()], "does not exist");
    is({}, {a => DNE()}, "does not exist");
    $events = intercept {
        is([], [E()]);
        is([undef], [DNE()]);
        is({a => undef}, {a => DNE()});
    };
    like(
        $events,
        array {
            filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
            event Ok => { pass => 0 };
            event Ok => { pass => 0 };
            event Ok => { pass => 0 };
        },
        "got failed event"
    );

    is([], [FDNE()], "does not exist");
    is({}, {a => FDNE()}, "does not exist");
    is([undef], [FDNE()], "false");
    is({a => undef}, {a => FDNE()}, "false");

    $events = intercept {
        is([1], [FDNE()]);
        is({a => 1}, {a => FDNE()});
    };
    like(
        $events,
        array {
            filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
            event Ok => { pass => 0 };
            event Ok => { pass => 0 };
        },
        "got failed event"
    );
};

subtest exact_ref => sub {
    my $ref = {};

    my $check = exact_ref($ref); my $line  = __LINE__;
    is($check->lines, [$line], "correct line");

    my $hash = {};
    my $events = intercept {
        is($ref,  $check, "pass");
        is($hash, $check, "fail");
    };

    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [["$hash", '==', "$ref", $line]],
                );
            };

            end;
        },
        "Got events"
    );
};

subtest string => sub {
    my $check = string "foo"; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is('foo', $check, "pass");
        is('bar', $check, "fail");
    };

    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => { pass => 0 };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/bar eq foo/, $line]],
                );
            };
            end;
        },
        "Got events"
    );

    my ($check1, $check2) = (string("foo", negate => 1), !string("foo"));
    $line = __LINE__ - 1;

    for $check ($check1, $check2) {
        is($check->lines, [$line], "Got line number");

        $events = intercept {
            is('bar', $check1, "pass");
            is('foo', $check1, "fail");
        };

        like(
            $events,
            array {
                event Ok => {pass => 1};
                fail_events Ok => {pass => 0};
                event Diag => sub {
                    call message => table(
                        header => [qw/GOT OP CHECK LNs/],
                        rows   => [[qw/foo ne foo/, $line]],
                    );
                };
                end;
            },
            "Got events"
        );
    }
};

subtest number => sub {
    my $check = number "22.0"; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is(22, $check, "pass");
        is("22.0", $check, "pass");
        is(12, $check, "fail");
        is('xxx', $check, "fail");
    };

    like(
        $events,
        array {
            event Ok => {pass => 1};
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/12 == 22.0/, $line]],
                );
            };

            fail_events Ok => { pass => 0 };
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/xxx == 22.0/, $line]],
                );
            };
            end;
        },
        "Got events"
    );

    my ($check1, $check2) = (number("22.0", negate => 1), !number("22.0"));
    $line = __LINE__ - 1;

    for $check ($check1, $check2) {
        is($check->lines, [$line], "Got line number");

        $events = intercept {
            is(12, $check, "pass");
            is(22, $check, "fail");
            is("22.0", $check, "fail");
            is('xxx', $check, "fail");
        };

        like(
            $events,
            array {
                event Ok => {pass => 1};
                fail_events Ok => { pass => 0 };
                event Diag => sub {
                    call message => table(
                        header => [qw/GOT OP CHECK LNs/],
                        rows   => [[qw/22 != 22.0/, $line]],
                    );
                };

                fail_events Ok => { pass => 0 };
                event Diag => sub {
                    call message => table(
                        header => [qw/GOT OP CHECK LNs/],
                        rows   => [[qw/22.0 != 22.0/, $line]],
                    );
                };

                fail_events Ok => { pass => 0 };
                event Diag => sub {
                    call message => table(
                        header => [qw/GOT OP CHECK LNs/],
                        rows   => [[qw/xxx != 22.0/, $line]],
                    );
                };

                end;
            },
            "Got events"
        );
    }
};

subtest match => sub {
    my $check = match qr/xyz/; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is('axyzb', $check, "pass");
        is('abcde', $check, "fail");
    };

    my $rx = "" . qr/xyz/;
    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/abcde =~/, "$rx", $line]],
                );
            };
            end;
        },
        "Got events"
    );
};

subtest '!match' => sub {
    my $check = !match qr/xyz/; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is('abcde', $check, "pass");
        is('axyzb', $check, "fail");
    };

    my $rx = "" . qr/xyz/;
    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/axyzb !~/, "$rx", $line]],
                );
            };
            end;
        },
        "Got events"
    );
};

subtest '!mismatch' => sub {
    my $check = !mismatch qr/xyz/; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is('axyzb', $check, "pass");
        is('abcde', $check, "fail");
    };

    my $rx = "" . qr/xyz/;
    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/abcde =~/, "$rx", $line]],
                );
            };
            end;
        },
        "Got events"
    );
};

subtest mismatch => sub {
    my $check = mismatch qr/xyz/; my $line = __LINE__;
    is($check->lines, [$line], "Got line number");

    my $events = intercept {
        is('abcde', $check, "pass");
        is('axyzb', $check, "fail");
    };

    my $rx = "" . qr/xyz/;
    like(
        $events,
        array {
            event Ok => {pass => 1};
            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[qw/axyzb !~/, "$rx", $line]],
                );
            };
            end;
        },
        "Got events"
    );
};

subtest check => sub {
    my @lines;
    my $one = validator sub { $_ ? 1 : 0 }; push @lines => __LINE__;
    my $two = validator two => sub { $_ ? 1 : 0 }; push @lines => __LINE__;
    my $thr = validator 't', thr => sub { $_ ? 1 : 0 }; push @lines => __LINE__;

    is($one->lines, [$lines[0]], "line 1");
    is($two->lines, [$lines[1]], "line 2");
    is($thr->lines, [$lines[2]], "line 3");

    my $events = intercept {
        is(1, $one, 'pass');
        is(1, $two, 'pass');
        is(1, $thr, 'pass');

        is(0, $one, 'fail');
        is(0, $two, 'fail');
        is(0, $thr, 'fail');
    };

    like(
        $events,
        array {
            event Ok => {pass => 1};
            event Ok => {pass => 1};
            event Ok => {pass => 1};

            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[0, 'CODE(...)', '<Custom Code>', $lines[0]]],
                );
            };

            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[0, 'CODE(...)', 'two', $lines[1]]],
                );
            };

            fail_events Ok => {pass => 0};
            event Diag => sub {
                call message => table(
                    header => [qw/GOT OP CHECK LNs/],
                    rows   => [[0, 't', 'thr', $lines[2]]],
                );
            };
            end;
        },
        "Got events"
    );
};

subtest prop => sub {
    like(
        dies { prop x => 1 },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [meta { my $x = prop x => 1 }] },
        qr/'prop' should only ever be called in void context/,
        "restricted context"
    );

    like(
        dies { [array { prop x => 1 }] },
        qr/'Test2::Compare::Array.*' does not support meta-checks/,
        "not everything supports properties"
    );
};

subtest end => sub {
    like(
        dies { end() },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [meta { end() }] },
        qr/'Test2::Compare::Meta.*' does not support 'ending'/,
        "Build does not support end"
    );

    like(
        dies { [array { [end()] }] },
        qr/'end' should only ever be called in void context/,
        "end context"
    );
};

subtest field => sub {
    like(
        dies { field a => 1 },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [array { field a => 1 }] },
        qr/'Test2::Compare::Array.*' does not support hash field checks/,
        "Build does not take fields"
    );

    like(
        dies { [hash { [field a => 1] }] },
        qr/'field' should only ever be called in void context/,
        "field context"
    );
};

subtest filter_items => sub {
    like(
        dies { filter_items {1} },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [hash { filter_items {1} }] },
        qr/'Test2::Compare::Hash.*' does not support filters/,
        "Build does not take filters"
    );

    like(
        dies { [array { [filter_items {1}] }] },
        qr/'filter_items' should only ever be called in void context/,
        "filter context"
    );
};

subtest item => sub {
    like(
        dies { item 0 => 'a' },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [hash { item 0 => 'a' }] },
        qr/'Test2::Compare::Hash.*' does not support array item checks/,
        "Build does not take items"
    );

    like(
        dies { [array { [ item 0 => 'a' ] }] },
        qr/'item' should only ever be called in void context/,
        "item context"
    );
};

subtest call => sub {
    like(
        dies { call foo => 1 },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [hash { call foo => 1 }] },
        qr/'Test2::Compare::Hash.*' does not support method calls/,
        "Build does not take methods"
    );

    like(
        dies { [object { [ call foo => 1 ] }] },
        qr/'call' should only ever be called in void context/,
        "call context"
    );
};

subtest check => sub {
    like(
        dies { check 'a' },
        qr/No current build/,
        "Need a build"
    );

    like(
        dies { [hash { check 'a' }] },
        qr/'Test2::Compare::Hash.*' is not a check-set/,
        "Build must support checks"
    );

    like(
        dies { [in_set(sub { [ check 'a' ] })] },
        qr/'check' should only ever be called in void context/,
        "check context"
    );
};

subtest meta => sub {
    my $x = bless {}, 'Foo';
    my $check = meta {
        prop blessed => 'Foo';
        prop reftype => 'HASH';
        prop this    => $x;
    };
    my @lines = map { __LINE__ - $_ } reverse 1 .. 5;

    is($x, $check, "meta pass");

    my $array = [];
    my $events = intercept { is($array, $check, "meta fail") };
    like(
        $events,
        array {
            fail_events Ok => sub { call pass => 0 };
            event Diag => sub {
                call message => table(
                    header => [qw/PATH GOT OP CHECK LNs/],
                    rows   => [
                        ["", $array, '', '<META CHECKS>', "$lines[0], $lines[4]"],
                        ['<blessed>', '<UNDEF>', '',   'Foo',  $lines[1]],
                        ['<reftype>', 'ARRAY',   'eq', 'HASH', $lines[2]],
                        ['<this>', $array, '', '<HASH>', $lines[3]],
                    ],
                );
            };
        },
        "got failure"
    );
};

subtest hash => sub {
    my $empty = hash { };

    my $full = hash {
        field a => 1;
        field b => 2;
    };

    my $closed = hash {
        field a => 1;
        field b => 2;
        end();
    };

    isa_ok($_, 'Test2::Compare::Base', 'Test2::Compare::Hash') for $empty, $full, $closed;

    is({}, $empty, "empty hash");
    is({a => 1}, $empty, "unclosed empty matches anything");

    is({a => 1, b => 2}, $full, "full exact match");
    is({a => 1, b => 2, c => 3 }, $full, "full with extra");

    is({a => 1, b => 2}, $closed, "closed");

    my $events = intercept {
        is([], $empty);
        is(undef, $empty);
        is(1, $empty);
        is('HASH', $empty);

        is({}, $full);
        is({a => 2, b => 2}, $full);

        is({a => 1, b => 2, c => 3}, $closed);
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;

    is(@$events, 7, '7 events');
    is($_->pass, 0, "event failed") for @$events;
};

subtest array => sub {
    my $empty = array { };

    my $simple = array {
        item 'a';
        item 'b';
        item 'c';
    };

    my $filtered = array {
        filter_items { grep { m/a/ } @_ };
        item 0 => 'a';
        item 1 => 'a';
        item 2 => 'a';
    };

    my $shotgun = array {
        item 1 => 'b';
        item 3 => 'd';
    };

    my $closed = array {
        item 0 => 'a';
        item 1 => 'b';
        item 2 => 'c';
        end;
    };

    is([], $empty, "empty array");
    is(['a'], $empty, "any array matches empty");

    is([qw/a b c/], $simple, "simple exact match");
    is([qw/a b c d e/], $simple, "simple with extra");

    is([qw/x a b c a v a t t/], $filtered, "filtered out unwanted values");

    is([qw/a b c d e/], $shotgun, "selected indexes only");

    is([qw/a b c/], $closed, "closed array");

    my $events = intercept {
        is({}, $empty);
        is(undef, $empty);
        is(1, $empty);
        is('ARRAY', $empty);

        is([qw/x y z/], $simple);
        is([qw/a b x/], $simple);
        is([qw/x b c/], $simple);

        is([qw/aa a a a b/], $filtered);

        is([qw/b c d e f/], $shotgun);

        is([qw/a b c d/], $closed);
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 10, "10 events");
    is($_->pass, 0, "event failed") for @$events;
};

subtest bag => sub {
    my $empty = bag { };

    my $simple = bag {
        item 'a';
        item 'b';
        item 'c';
    };

    my $closed = array {
        item 0 => 'a';
        item 1 => 'b';
        item 2 => 'c';
        end;
    };

    is([], $empty, "empty array");
    is(['a'], $empty, "any array matches empty");

    is([qw/a b c/], $simple, "simple exact match");
    is([qw/b c a/], $simple, "simple out of order");
    is([qw/a b c d e/], $simple, "simple with extra");
    is([qw/b a d e c/], $simple, "simple with extra, out of order");

    is([qw/a b c/], $closed, "closed array");

    my $events = intercept {
        is({}, $empty);
        is(undef, $empty);
        is(1, $empty);
        is('ARRAY', $empty);

        is([qw/x y z/], $simple);
        is([qw/a b x/], $simple);
        is([qw/x b c/], $simple);

        is([qw/a b c d/], $closed);
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 8, "8 events");
    is($_->pass, 0, "event failed") for @$events;
};

subtest object => sub {
    my $empty = object { };

    my $simple = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
    };

    my $array = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        item 0 => 'x';
        item 1 => 'y';
    };

    my $closed_array = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        item 0 => 'x';
        item 1 => 'y';
        end();
    };

    my $hash = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        field x => 1;
        field y => 2;
    };

    my $closed_hash = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        field x => 1;
        field y => 2;
        end();
    };

    my $meta = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        prop blessed => 'ObjectFoo';
        prop reftype => 'HASH';
    };

    my $mix = object {
        call foo => 'foo';
        call bar => 'bar';
        call_list many => [1,2,3,4];
        call_hash many => {1=>2,3=>4};
        call [args => qw(a b)] => {a=>'b'};
        field x => 1;
        field y => 2;
        prop blessed => 'ObjectFoo';
        prop reftype => 'HASH';
    };

    my $obf = mock 'ObjectFoo' => (add => [
        foo => sub { 'foo' },
        bar => sub { 'bar' },
        baz => sub {'baz'},
        many => sub { (1,2,3,4) },
        args => sub { shift; +{@_} },
    ]);
    my $obb = mock 'ObjectBar' => (add => [
        foo => sub { 'nop' },
        baz => sub { 'baz' },
        many => sub { (1,2,3,4) },
        args => sub { shift; +{@_} },
    ]);

    is(bless({}, 'ObjectFoo'), $empty, "Empty matches any object");
    is(bless({}, 'ObjectBar'), $empty, "Empty matches any object");

    is(bless({}, 'ObjectFoo'), $simple, "simple match hash");
    is(bless([], 'ObjectFoo'), $simple, "simple match array");

    is(bless([qw/x y/], 'ObjectFoo'), $array, "array match");
    is(bless([qw/x y z/], 'ObjectFoo'), $array, "array match");

    is(bless([qw/x y/], 'ObjectFoo'), $closed_array, "closed array");

    is(bless({x => 1, y => 2}, 'ObjectFoo'), $hash, "hash match");
    is(bless({x => 1, y => 2, z => 3}, 'ObjectFoo'), $hash, "hash match");

    is(bless({x => 1, y => 2}, 'ObjectFoo'), $closed_hash, "closed hash");

    is(bless({}, 'ObjectFoo'), $meta, "meta match");

    is(bless({x => 1, y => 2, z => 3}, 'ObjectFoo'), $mix, "mix");

    my $events = intercept {
        is({}, $empty);
        is(undef, $empty);
        is(1, $empty);
        is('ARRAY', $empty);

        is(bless({}, 'ObjectBar'), $simple, "simple match hash");
        is(bless([], 'ObjectBar'), $simple, "simple match array");

        is(bless([qw/a y/], 'ObjectFoo'), $array, "array match");
        is(bless([qw/a y z/], 'ObjectFoo'), $array, "array match");

        is(bless([qw/x y z/], 'ObjectFoo'), $closed_array, "closed array");

        is(bless({x => 2, y => 2}, 'ObjectFoo'), $hash, "hash match");
        is(bless({x => 2, y => 2, z => 3}, 'ObjectFoo'), $hash, "hash match");

        is(bless({x => 1, y => 2, z => 3}, 'ObjectFoo'), $closed_hash, "closed hash");

        is(bless({}, 'ObjectBar'), $meta, "meta match");
        is(bless([], 'ObjectFoo'), $meta, "meta match");

        is(bless({}, 'ObjectFoo'), $mix, "mix");
        is(bless([], 'ObjectFoo'), $mix, "mix");
        is(bless({x => 1, y => 2, z => 3}, 'ObjectBar'), $mix, "mix");
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 17, "17 events");
    is($_->pass, 0, "event failed") for @$events;

};

subtest event => sub {
    like(
        dies { event 0 => {} },
        qr/type is required/,
        "Must specify event type"
    );

    my $one = event Ok => {};
    is($one->meta->items->[0]->[1], 'Test2::Event::Ok', "Event type check");

    $one = event '+Foo::Event::Diag' => {};
    is($one->meta->items->[0]->[1], 'Foo::Event::Diag', "Event type check with +");

    my $empty = event 'Ok';
    isa_ok($empty, 'Test2::Compare::Event');

    like(
        dies { event Ok => 'xxx' },
        qr/'xxx' is not a valid event specification/,
        "Invalid spec"
    );

    my $from_sub = event Ok => sub {
        call pass  => 1;
        field name => 'pass';
    };

    my $from_hash = event Ok => {pass => 1, name => 'pass'};

    my $from_build = array { event Ok => {pass => 1, name => 'pass'} };

    my $pass = intercept { ok(1, 'pass') };
    my $fail = intercept { ok(0, 'fail') };
    my $diag = intercept { diag("hi") };

    is($pass->[0], $empty,      "empty matches any event of the type");
    is($fail->[0], $empty,      "empty on a failed event");
    is($pass->[0], $from_sub,   "builder worked");
    is($pass->[0], $from_hash,  "hash spec worked");
    is($pass,      $from_build, "worked in build");

    my $events = intercept {
        is($diag->[0], $empty);

        is($fail->[0], $from_sub,   "builder worked");
        is($fail->[0], $from_hash,  "hash spec worked");
        is($fail,      $from_build, "worked in build");
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 4, "4 events");
    is($_->pass, 0, "event failed") for @$events;

    like(
        dies { event Ok => {}; 1 },
        qr/No current build!/,
        "Need a build!"
    );
};

subtest sets => sub {
    subtest check_set => sub {
        is(
            'foo',
            check_set(sub { check 'foo'; check match qr/fo/; check match qr/oo/ }),
            "matches everything in set"
        );

        is(
            'foo',
            check_set('foo', match qr/fo/, match qr/oo/),
            "matches everything in set"
        );

        like(
            intercept {
                is('fox', check_set(sub{ check match qr/fo/; check 'foo' }));
                is('fox', check_set(match qr/fo/, 'foo'));
            },
            array {
                filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
                event Ok => { pass => 0 };
                event Ok => { pass => 0 };
                end;
            },
            "Failed cause not all checks passed"
        );
    };

    subtest in_set => sub {
        is(
            'foo',
            in_set(sub { check 'x'; check 'y'; check 'foo' }),
            "Item is in set"
        );
        is(
            'foo',
            in_set(qw/x y foo/),
            "Item is in set"
        );

        like(
            intercept {
                is('fox', in_set(sub{ check 'x'; check 'foo' }));
                is('fox', in_set('x', 'foo'));
            },
            array {
                filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
                event Ok => { pass => 0 };
                event Ok => { pass => 0 };
                end;
            },
            "Failed cause not all checks passed"
        );
    };

    subtest not_in_set => sub {
        is(
            'foo',
            not_in_set(sub { check 'x'; check 'y'; check 'z' }),
            "Item is not in set"
        );
        is(
            'foo',
            not_in_set(qw/x y z/),
            "Item is not in set"
        );

        like(
            intercept {
                is('fox', not_in_set(sub{ check 'x'; check 'fox' }));
                is('fox', not_in_set('x', 'fox'));
            },
            array {
                filter_items { grep { !$_->isa('Test2::Event::Diag') } @_ };
                event Ok => { pass => 0 };
                event Ok => { pass => 0 };
                end;
            },
            "Failed cause not all checks passed"
        );

    };
};

subtest regex => sub {
    is(qr/abc/, qr/abc/, "same regex");

    my $events = intercept {
        is(qr/abc/i, qr/abc/, "Wrong flags");
        is(qr/abc/, qr/abcd/, "wrong pattern");
        is(qr/abc/, exact_ref(qr/abc/), "not an exact match");
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 3, "3 events");
    ok(!$_->{pass}, "Event was a failure") for @$events
};

subtest isnt => sub {
    isnt('a', 'b', "a is not b");
    isnt({}, [], "has is not array");
    isnt(0, 1, "0 is not 1");

    my $events = intercept {
        isnt([], []);
        isnt('a', 'a');
        isnt(1, 1);
        isnt({}, {});
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 4, "4 events");
    ok(!$_->{pass}, "Event was a failure") for @$events
};

subtest unlike => sub {
    unlike('a', 'b', "a is not b");
    unlike({}, [], "has is not array");
    unlike(0, 1, "0 is not 1");
    unlike('aaa', qr/bbb/, "aaa does not match /bbb/");

    my $events = intercept {
        unlike([], []);
        unlike('a', 'a');
        unlike(1, 1);
        unlike({}, {});
        unlike( 'foo', qr/o/ );
    };

    @$events = grep {$_->isa('Test2::Event::Ok')} @$events;
    is(@$events, 5, "5 events");
    ok(!$_->{pass}, "Event was a failure") for @$events
};

subtest all_items => sub {
    is(
        [qw/a aa aaa/],
        array {
            all_items match qr/^a+$/;
            item 'a';
            item 'aa';
        },
        "All items match regex"
    );

    my @lines;
    my $array = [qw/a aa aaa/];
    my $regx = qr/^b+$/;
    my $events = intercept {
        is(
            $array,
            array {
                all_items match $regx;  push @lines => __LINE__;
                item 'b';               push @lines => __LINE__;
                item 'aa';              push @lines => __LINE__;
                end;
            },
            "items do not all match, and diag reflects all issues, and in order"
        );
    };
    is(
        $events,
        array {
            fail_events Ok => {pass => 0};
            event Diag => {
                message => table(
                    header => [qw/PATH GOT OP CHECK LNs/],
                    rows   => [
                        ['', "$array", '', "<ARRAY>", ($lines[0] - 1) . ", " . ($lines[-1] + 2)],
                        ['[0]', 'a',   '=~',      $regx,              $lines[0]],
                        ['[0]', 'a',   'eq',      'b',                $lines[1]],
                        ['[1]', 'aa',  '=~',      $regx,              $lines[0]],
                        ['[2]', 'aaa', '=~',      $regx,              $lines[0]],
                        ['[2]', 'aaa', '!exists', '<DOES NOT EXIST>', ''],
                    ],
                ),
            };

        },
        "items do not all match, and diag reflects all issues, and in order"
    );
};

subtest all_keys_and_vals => sub {
    is(
        {a => 'a', 'aa' => 'aa', 'aaa' => 'aaa'},
        hash {
            all_values match qr/^a+$/;
            all_keys match qr/^a+$/;
            field a   => 'a';
            field aa  => 'aa';
            field aaa => 'aaa';
        },
        "All items match regex"
    );

    my @lines;
    my $hash = {a => 'a', 'aa' => 'aa', 'aaa' => 'aaa'};
    my $regx = qr/^b+$/;
    my $events = intercept {
        is(
            $hash,
            hash {
                all_keys match $regx;   push @lines => __LINE__;
                all_vals match $regx;   push @lines => __LINE__;
                field aa => 'aa';       push @lines => __LINE__;
                field b  => 'b';        push @lines => __LINE__;
                end;
            },
            "items do not all match, and diag reflects all issues, and in order"
        );
    };
    is(
        $events,
        array {
            fail_events Ok => {pass => 0};
            event Diag => {
                message => table(
                    header => [qw/PATH GOT OP CHECK LNs/],
                    rows   => [
                        ['',            $hash,              '',        '<HASH>',           join(', ', $lines[0] - 1, $lines[-1] + 2)],
                        ['{aa} <KEY>',  'aa',               '=~',      $regx,              $lines[0]],
                        ['{aa}',        'aa',               '=~',      $regx,              $lines[1]],
                        ['{b}',         '<DOES NOT EXIST>', '',        'b',                $lines[3]],
                        ['{a} <KEY>',   'a',                '=~',      $regx,              $lines[0]],
                        ['{a}',         'a',                '=~',      $regx,              $lines[1]],
                        ['{a}',         'a',                '!exists', '<DOES NOT EXIST>', '',],
                        ['{aaa} <KEY>', 'aaa',              '=~',      $regx,              $lines[0]],
                        ['{aaa}',       'aaa',              '=~',      $regx,              $lines[1]],
                        ['{aaa}',       'aaa',              '!exists', '<DOES NOT EXIST>', ''],
                    ],
                ),
            };
        },
        "items do not all match, and diag reflects all issues, and in order"
    );
};


done_testing;
