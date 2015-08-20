use Test::Stream -Spec, Class => ['Test::Stream::Delta'], 'Defer';

can_ok($CLASS, qw/check/);
is(
    $CLASS->can('chk'),
    $CLASS->can('check'),
    "chk is aliased to check"
);

my $one = $CLASS->new();
isa_ok($one, $CLASS);

my $check1 = Test::Stream::Compare::Value->new(input => 'x');
my $check2 = Test::Stream::Compare::Value->new(input => 'y');

$one = $CLASS->new(check => $check1);
same_ref($one->chk, $check1, "Got our check");
same_ref($one->check, $check1, "Got our check aliased");

$one = $CLASS->new(chk => $check2);
same_ref($one->chk, $check2, "Got our check");
same_ref($one->check, $check2, "Got our check aliased");

like(
    dies { $CLASS->new(check => $check1, chk => $check2) },
    qr/Cannot specify both 'check' and 'chk' as arguments/,
    "Cannot specify both chk and check"
);

tests render_got => sub {
    my $one = $CLASS->new;

    is($one->render_got, '<UNDEF>', "'got' is undef");

    $one->set_exception('foo');
    is($one->render_got, '<EXCEPTION: foo>', "Exception always wins");

    $one->clear_exception();
    $one->set_dne('got');
    is($one->render_got, '<DOES NOT EXIST>', "'got' does not exist");

    $one->set_dne('check');
    is($one->render_got, '<UNDEF>', "'got' does not exist");

    $one->clear_dne;
    $one->set_got('a');
    is($one->render_got, 'a', "'got' value");

    $one->set_got({});
    like($one->render_got, qr/HASH\(.*\)/, "'got' ref value");
};

tests render_check => sub {
    my $one   = $CLASS->new;
    my $check = Test::Stream::Compare::Value->new(input => 'xyz');

    is($one->render_check, '<UNDEF>', "check is undef");

    $one->set_dne('got');
    is($one->render_check, '<UNDEF>', "check is undef and dne is 'got'");

    $one->set_dne('check');
    is($one->render_check, '<DOES NOT EXIST>', "check does not exit");

    $one->clear_dne;
    $one->set_check($check);
    is($one->render_check, $check->render, "valid check is rendered");
};

tests _full_id => sub {
    my $fid = $CLASS->can('_full_id');

    is($fid->(undef,    'xxx'), '<xxx>', "no type means <ID>");
    is($fid->('META',   'xxx'), '<xxx>', "META type means <ID>");
    is($fid->('SCALAR', '$*'),  '$*',    "SCALAR type means ID is unchanged");
    is($fid->('HASH',   'xxx'), '{xxx}', "HASH type means ID is wrapped in {}");
    is($fid->('ARRAY',  '12'),  '[12]',  "ARRAY type means ID is wrapped in []");
    is($fid->('METHOD', 'foo'), 'foo()', "METHOD type gets () postfix");
};

tests _arrow_id => sub {
    my $aid = $CLASS->can('_arrow_id');

    is($aid->('xxx',   undef),    ' ',  "undef gets a space, not an arrow");
    is($aid->('xxx',   'META'),   ' ',  "Meta gets a space, not an arrow");
    is($aid->('xxx',   'METHOD'), '->', "Method always needs an arrow");
    is($aid->('xxx',   'SCALAR'), '->', "Scalar always needs an arrow");
    is($aid->('xxx',   'HASH'),   '->', "Hash usually needs an arrow");
    is($aid->('xxx',   'ARRAY'),  '->', "Array usually needs an arrow");
    is($aid->('{xxx}', 'HASH'),   '',   "Hash needs no arrow after hash");
    is($aid->('{xxx}', 'ARRAY'),  '',   "Array needs no arrow after hash");
    is($aid->('[xxx]', 'HASH'),   '',   "Hash needs no arrow after array");
    is($aid->('[xxx]', 'ARRAY'),  '',   "Array needs no arrow after array");
    is($aid->('<xxx>', 'xxx'),    '->', "Need an arrow after meta, or after a method");
    is($aid->('xxx()', 'xxx'),    '->', "Need an arrow after meta, or after a method");
    is($aid->('$VAR',  'xxx'),    '->', "Need an arrow after the initial ref");
    is($aid->('xxx',   ''),       ' ',  "space");
    is($aid->('',      ''),       '',   "No arrow needed");
};

tests _join_id => sub {
    my $jid = $CLASS->can('_join_id');

    is($jid->('{path}', [undef, 'id']), "{path} <id>", "Hash + undef");
    is($jid->('[path]', [undef, 'id']), "[path] <id>", "Array + undef");
    is($jid->('path',   [undef, 'id']), "path <id>",   "path + undef");
    is($jid->('<path>', [undef, 'id']), "<path> <id>", "meta + undef");
    is($jid->('path()', [undef, 'id']), "path() <id>", "meth + undef");
    is($jid->('$VAR',   [undef, 'id']), '$VAR <id>',   '$VAR + undef');
    is($jid->('',       [undef, 'id']), "<id>",        "empty + undef");

    is($jid->('{path}', ['META', 'id']), "{path} <id>", "hash + meta");
    is($jid->('[path]', ['META', 'id']), "[path] <id>", "array + meta");
    is($jid->('path',   ['META', 'id']), "path <id>",   "path + meta");
    is($jid->('<path>', ['META', 'id']), "<path> <id>", "meta + meta");
    is($jid->('path()', ['META', 'id']), "path() <id>", "meth + meta");
    is($jid->('$VAR',   ['META', 'id']), '$VAR <id>',   '$VAR + meta');
    is($jid->('',       ['META', 'id']), "<id>",        "empty + meta");

    is($jid->('{path}', ['SCALAR', '$*']), '{path}->$*', "Hash + scalar");
    is($jid->('[path]', ['SCALAR', '$*']), '[path]->$*', "Array + scalar");
    is($jid->('path',   ['SCALAR', '$*']), 'path->$*',   "Path + scalar");
    is($jid->('<path>', ['SCALAR', '$*']), '<path>->$*', "Meta + scalar");
    is($jid->('path()', ['SCALAR', '$*']), 'path()->$*', "Meth + scalar");
    is($jid->('$VAR',   ['SCALAR', '$*']), '$VAR->$*',   '$VAR + scalar');
    is($jid->('',       ['SCALAR', '$*']), '$*',         "Empty + scalar");

    is($jid->('{path}', ['HASH', 'id']), "{path}{id}",   "Hash + hash");
    is($jid->('[path]', ['HASH', 'id']), "[path]{id}",   "Array + hash");
    is($jid->('path',   ['HASH', 'id']), "path->{id}",   "Path + hash");
    is($jid->('<path>', ['HASH', 'id']), "<path>->{id}", "Meta + hash");
    is($jid->('path()', ['HASH', 'id']), "path()->{id}", "Meth + hash");
    is($jid->('$VAR',   ['HASH', 'id']), '$VAR->{id}',   '$VAR + hash');
    is($jid->('',       ['HASH', 'id']), "{id}",         "Empty + hash");

    is($jid->('{path}', ['ARRAY', '12']), "{path}[12]",   "Hash + array");
    is($jid->('[path]', ['ARRAY', '12']), "[path][12]",   "Array + array");
    is($jid->('path',   ['ARRAY', '12']), "path->[12]",   "Path + array");
    is($jid->('<path>', ['ARRAY', '12']), "<path>->[12]", "Meta + array");
    is($jid->('path()', ['ARRAY', '12']), "path()->[12]", "Meth + array");
    is($jid->('$VAR',   ['ARRAY', '12']), '$VAR->[12]',   '$VAR + array');
    is($jid->('',       ['ARRAY', '12']), "[12]",         "Empty + array");

    is($jid->('{path}', ['METHOD', 'id']), "{path}->id()", "Hash + method");
    is($jid->('[path]', ['METHOD', 'id']), "[path]->id()", "Array + method");
    is($jid->('path',   ['METHOD', 'id']), "path->id()",   "Path + method");
    is($jid->('<path>', ['METHOD', 'id']), "<path>->id()", "Meta + method");
    is($jid->('path()', ['METHOD', 'id']), "path()->id()", "Meth + method");
    is($jid->('$VAR',   ['METHOD', 'id']), '$VAR->id()',   '$VAR + method');
    is($jid->('',       ['METHOD', 'id']), "id()",         "Empty + method");
};

tests should_show => sub {
    my $one = $CLASS->new(verified => 0);
    ok($one->should_show, "not verified, always show");

    $one->set_verified(1);
    ok(!$one->should_show, "verified, do not show");

    my $check = Test::Stream::Compare::Value->new(input => 'xyz');
    $one->set_chk($check);
    ok(!$one->should_show, "verified, check is uninteresting");

    $check->set_lines([1,2]);
    ok(!$one->should_show, "verified, check has lines but no file");

    $check->set_file('foo');
    ok(!$one->should_show, "verified, check has lines different file");

    $check->set_file(__FILE__);
    ok($one->should_show, "Have lines and same file, should show for debug purposes");
};

tests filter_visible => sub {
    my $root   = $CLASS->new(verified => 1);
    my $child1 = $CLASS->new(verified => 0, id => [HASH => 'a']);
    my $child2 = $CLASS->new(verified => 1, id => [HASH => 'b']);
    my $grand1 = $CLASS->new(verified => 0, id => [ARRAY => 0], children => []);
    my $grand2 = $CLASS->new(verified => 0, id => [ARRAY => 1], children => []);

    $root->set_children([$child1, $child2]);
    $child2->set_children([$grand1, $grand2]);

    is(
        $root->filter_visible,
        [
            ['{a}',    $child1],
            ['{b}[0]', $grand1],
            ['{b}[1]', $grand2],
        ],
        "Got visible ones"
    );
};

tests table_header => sub {
    is($CLASS->table_header, [qw/PATH LNs GOT OP CHECK LNs/], "got header");
};

tests table_op => sub {
    my $one = $CLASS->new(verified => 0);
    is($one->table_op, '!exists', "no op if there is no check");

    my $check = Test::Stream::Compare::Value->new(input => 'xyz');
    $one->set_chk($check);
    $one->set_got('foo');
    is($one->table_op, 'eq', "got op");

    $one->set_dne('anything');
    is($one->table_op, 'eq', "got op when dne is set to something other than 'got'");

    $one->set_dne('got');
    is($one->table_op, '', "Called check->operator without args since dne is 'got'");
};

tests table_check_lines => sub {
    my $one = $CLASS->new(verified => 0);
    is($one->table_check_lines, '', 'no lines without a check');

    my $check = Test::Stream::Compare::Value->new(input => 'xyz');
    $one->set_chk($check);
    is($one->table_check_lines, '', 'check has no lines');

    $check->set_lines([]);
    is($one->table_check_lines, '', 'check has lines, but it is empty');

    $check->set_lines([2, 4, 6]);
    is($one->table_check_lines, '2, 4, 6', 'got lines');
};

tests table_got_lines => sub {
    my $one = $CLASS->new(verified => 0);
    is($one->table_got_lines, '', "no lines without a check");

    my $check = Test::Stream::Compare::Value->new(input => 'xyz');
    $one->set_chk($check);
    $one->set_dne('got');
    is($one->table_got_lines, '', "no lines when 'got' is dne");

    $one->set_dne('anything');
    is($one->table_got_lines, '', "no lines found with other dne");

    $one->set_dne('');
    is($one->table_got_lines, '', "no lines found by check");

    mock 'Test::Stream::Compare' => (
        override => [
            got_lines => sub {(2, 4, 6)},
        ],
    );

    is($one->table_got_lines, '2, 4, 6', "got lines");
};

tests table_rows => sub {
    my $one = $CLASS->new(verified => 0);

    # These are tested above, mocking here for simplicity
    my $mock = mock $CLASS => (
        override => [
            filter_visible    => sub { [['{foo}', $one], ['{bar}', $one]] },
            render_check      => sub { 'CHECK!' },
            render_got        => sub { 'GOT!' },
            table_op          => sub { 'OP!' },
            table_check_lines => sub { 'CHECK LINES!' },
            table_got_lines   => sub { 'GOT LINES!' },
        ],
    );

    my $rows = $one->table_rows;
    $mock = undef;

    is(
        $rows,
        [
            ['{foo}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
            ['{bar}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ],
        "got rows"
    );
};

tests table => sub {
    local $ENV{TS_MAX_DELTA} = 10;
    my $rows;
    my $mock = mock $CLASS => (override => [table_rows => sub { return $rows }]);
    my $one = $CLASS->new();

    $rows = [
        ['{foo}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{bar}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{baz}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{bat}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
    ];

    def is => (
        [$one->table],
        [
            '+-------+------------+------+-----+--------+--------------+',
            '| PATH  | LNs        | GOT  | OP  | CHECK  | LNs          |',
            '+-------+------------+------+-----+--------+--------------+',
            '| {foo} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '| {bar} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '| {baz} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '| {bat} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '+-------+------------+------+-----+--------+--------------+',
        ],
        "Got expected table"
    );

    $rows = [
        ['{foo}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{bar}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{baz}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
        ['{bat}', 'GOT LINES!', 'GOT!', 'OP!', 'CHECK!', 'CHECK LINES!'],
    ];

    $ENV{TS_MAX_DELTA} = 2;
    def is => (
        [$one->table],
        [
            '+-------+------------+------+-----+--------+--------------+',
            '| PATH  | LNs        | GOT  | OP  | CHECK  | LNs          |',
            '+-------+------------+------+-----+--------+--------------+',
            '| {foo} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '| {bar} | GOT LINES! | GOT! | OP! | CHECK! | CHECK LINES! |',
            '+-------+------------+------+-----+--------+--------------+',
            '************************************************************',
            '* Stopped after 2 differences.                             *',
            '* Set the TS_MAX_DELTA environment var to raise the limit. *',
            '* Set it to 0 for no limit.                                *',
            '************************************************************',
        ],
        "Got expected table and warning"
    );

    $ENV{TS_MAX_DELTA} = 25;
    $rows = [
        ['{foo}', '', '', '', '', ''],
        ['{bar}', '', '', '', '', ''],
        ['{baz}', '', '', '', '', ''],
        ['{bat}', '', '', '', '', ''],
    ];

    def is => (
        [$one->table],
        [
            '+-------+-----+-------+',
            '| PATH  | GOT | CHECK |',
            '+-------+-----+-------+',
            '| {foo} |     |       |',
            '| {bar} |     |       |',
            '| {baz} |     |       |',
            '| {bat} |     |       |',
            '+-------+-----+-------+',
        ],
        "'GOT' and 'CHECK' never collapse"
    );

    $mock = undef;
    delete $ENV{TS_MAX_DELTA};

    do_def();
};

done_testing;
