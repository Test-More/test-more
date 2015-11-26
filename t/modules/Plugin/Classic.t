use Test::Stream(
    class => 'Test::Stream::Plugin::Classic',
    -Classic,
    -Tester,
    Defer,
    Compare => [
        '-all',
        is   => {-as   => '_is'},
        like => {'-as' => '_like'}
    ]
);

imported_ok(qw/is is_deeply like/);

my $ref = {};

is(undef, undef, "undef is undef");

is("foo", "foo", 'foo check');
is($ref,   "$ref", "flat check, ref as string right");
is("$ref", $ref,   "flat check, ref as string left");

isnt("bar", "foo", 'not foo check');
isnt({},   "$ref", "negated flat check, ref as string right");
isnt("$ref", {},   "negated flat check, ref as string left");

like('aaa', qr/a/, "have an a");
like('aaa', 'a', "have an a, not really a regex");

unlike('bbb', qr/a/, "do not have an a");
unlike('bbb', 'a', "do not have an a, not really a regex");

# Failures
my $events = intercept {
    def ok => (!is('foo', undef, "undef check"),     "undef check");
    def ok => (!is(undef, foo,   "undef check"),     "undef check");
    def ok => (!is('foo', 'bar', "string mismatch"), "string mismatch");
    def ok => (!isnt('foo', 'foo', "undesired match"), "undesired match");
    def ok => (!like('foo', qr/a/, "no match"), "no match");
    def ok => (!unlike('foo', qr/o/, "unexpected match"), "unexpected match");
};

do_def;

is_deeply(
    $events,
    array {
        event Ok => { pass => 0 };
        event Ok => { pass => 0 };
        event Ok => { pass => 0 };
        event Ok => { pass => 0 };
        event Ok => { pass => 0 };
        event Ok => { pass => 0 };
        end;
    },
    "got failure events"
);

# is_deeply uses the same algorithm as the 'Compare' plugin, so it is already
# tested over there.
is_deeply(
    {foo => 1, bar => 'baz'},
    {foo => 1, bar => 'baz'},
    "Deep compare"
);

{
    package Foo;
    use overload '""' => sub { 'xxx' };
}
my $foo = bless({}, 'Foo');
like($foo, qr/xxx/, "overload");

done_testing;
