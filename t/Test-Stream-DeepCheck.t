use Test::Stream;

use Test::Stream::Tester;
use Test::Stream::DebugInfo;
use Test::Stream::DeepCheck qw{
    strict_compare relaxed_compare
    array hash
    check
    field elem
    filter end
    meta call
    object hash_object array_object
    STRUCT
    build_object
    convert
};

my $dbg = Test::Stream::DebugInfo->new(frame => [ __PACKAGE__, __FILE__, __LINE__, 'foo' ]);

my $check = convert(undef, $dbg, 0);
isa_ok($check, 'Test::Stream::DeepCheck::Check');
is($check->op, '!defined', "Check for undefined");

$check = convert('foo', $dbg, 0);
isa_ok($check, 'Test::Stream::DeepCheck::Check');
is($check->op, 'eq', "Check for string equality");

$check = convert(100, $dbg, 'strict');
isa_ok($check, 'Test::Stream::DeepCheck::Check');
is($check->op, 'eq', "String equality in strict mode");

$check = convert(100, $dbg, 0);
isa_ok($check, 'Test::Stream::DeepCheck::Check');
is($check->op, '==', "Numeric equality in relaxed mode");

my $check2 = convert($check, $dbg, 0);
ok($check == $check2, "Check is not modified by convert");

$check = convert(qr/foo/, $dbg, 0);
is($check->op, '=~', "Regex is a regex check in relaxed mode");

$check = convert(qr/foo/, $dbg, 'strict');
is($check->op, '==', "Regex is a ref check in strict mode");

my $ref = \*STDOUT;
$check = convert($ref, $dbg, 'strict');
is($check->op, '==', "ref check strict");

$check = convert($ref, $dbg, 0);
is($check->op, '==', "ref check relaxed");

$check = convert({foo => 1}, $dbg, 0);
isa_ok($check, 'Test::Stream::DeepCheck::Hash');

$check = convert([qw/fooo bar/], $dbg, 0);
isa_ok($check, 'Test::Stream::DeepCheck::Array');

my $reg = qr/aaa/;
strict_compare(
    {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
    {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
    "Match strict"
);

relaxed_compare(
    {foo => 1, bar => [ 'a' ], baz => { a => 1, b => 'ignored' }, reg => 'aaa', extra => 'not checked'},
    {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
    "Match relaxed"
);

my $FILE = __FILE__;
events_are(
    intercept {
        strict_compare(
            {foo => 1, bar => [ 'a' ], baz => { a => 1, bad => 'oops', bad2 => 1 }, reg => $reg},
            hash {
                field foo => 1;
                field bar => array {
                    elem 'a';
                };
                field baz => hash {
                    field a => 1;
                };
                field reg => $reg;
            },
            'Missed one'
        );
    },
    events {
        meta 'Check Type', 'reftype', 'ARRAY';
        event Ok => sub {
            event_call pass => 0;
            event_call diag => [
                qr/Failed test 'Missed one'/,
                qq|Path: \$_->{'baz'}->{'bad', 'bad2'}
Failed Check: Expected no more fields, got 'bad', 'bad2'
$FILE
76 {
81   'baz': {
--     'bad', 'bad2'|,
            ];
        };
        end_events;
    },
    "Mismatch"
);

my @args;
my $events = intercept {
    strict_compare(
        { a => { b => [ qw/a b c/ ] } },
        { a => { b => [ qw/a b d/ ] } },
        "Foo",
        sub { @args = @_; 'added debug' },
    );
};

is_deeply(
    [@args],
    [
        { a => { b => [ qw/a b c/ ] } },
        qw/a b 2/,
    ],
    "Got expected diag callback args"
);

is($events->[0]->diag->[-1], 'added debug', "got the debug line");

done_testing;
