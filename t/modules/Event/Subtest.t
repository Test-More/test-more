use Test::Stream;

use Test::Stream::TAP qw/OUT_STD OUT_ERR/;
use Test::Stream::Event::Subtest;
my $st = 'Test::Stream::Event::Subtest';

my $dbg = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']);
my $one = $st->new(
    debug     => $dbg,
    pass      => 1,
    buffered  => 1,
    name      => 'foo',
);

isa_ok($one, $st, 'Test::Stream::Event::Ok');
is($one->subevents, [], "subevents is an arrayref");

is(
    [$one->to_tap(5)],
    [
        [OUT_STD, "ok 5 - foo {\n"],
        [OUT_STD, "}\n"],
    ],
    "Got Buffered TAP output"
);

$one->set_buffered(0);
is(
    [$one->to_tap(5)],
    [
        [OUT_STD, "ok 5 - foo\n"],
    ],
    "Got Unbuffered TAP output"
);

$dbg = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']);
$one = $st->new(
    debug     => $dbg,
    pass      => 0,
    buffered  => 1,
    name      => 'bar',
    subevents => [
        Test::Stream::Event::Ok->new(debug => $dbg, name => 'first',  pass => 1),
        Test::Stream::Event::Ok->new(debug => $dbg, name => 'second', pass => 0),
        Test::Stream::Event::Ok->new(debug => $dbg, name => 'third',  pass => 1),

        Test::Stream::Event::Diag->new(debug => $dbg, message => 'blah blah'),

        Test::Stream::Event::Plan->new(debug => $dbg, max => 3),
    ],
);

is(
    [$one->to_tap(5)],
    [
        [OUT_STD, "not ok 5 - bar {\n"],
        [OUT_STD, "    ok 1 - first\n"],
        [OUT_STD, "    not ok 2 - second\n"],
        [OUT_STD, "    ok 3 - third\n"],
        [OUT_ERR, "    # blah blah\n"],
        [OUT_STD, "    1..3\n"],
        [OUT_STD, "}\n"],
    ],
    "Got Buffered TAP output"
);

$one->set_buffered(0);
is(
    [$one->to_tap(5)],
    [
        # In unbuffered TAP the subevents are rendered outside of this.
        [OUT_STD, "not ok 5 - bar\n"],
    ],
    "Got Unbuffered TAP output"
);

done_testing;
