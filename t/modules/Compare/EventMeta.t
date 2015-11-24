use Test::Stream -V1, Class => ['Test::Stream::Compare::EventMeta'];
use Test::Stream::Util qw/get_tid/;

my $one = $CLASS->new();

my $dbg = Test::Stream::DebugInfo->new(frame => ['Foo', 'foo.t', 42, 'foo']);
my $Ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => 1);

is($one->get_prop_file($Ok),    'foo.t',            "file");
is($one->get_prop_line($Ok),    42,                 "line");
is($one->get_prop_package($Ok), 'Foo',              "package");
is($one->get_prop_subname($Ok), 'foo',              "subname");
is($one->get_prop_todo($Ok),    undef,              "todo (unset)");
is($one->get_prop_trace($Ok),   'at foo.t line 42', "trace");
is($one->get_prop_pid($Ok),     $$,                 "pid");
is($one->get_prop_tid($Ok),     get_tid,            "tid");

like(
    warning { is($one->get_prop_skip($Ok), undef, "skip (unset)") },
    qr/Use of 'skip' property is deprecated/,
    "Got skip warning"
);

$Ok->debug->set_todo('a');
is($one->get_prop_todo($Ok), 'a', "todo (set)");

# Deprecated
warns {
    $Ok->debug->set_skip('b'); 
    is($one->get_prop_skip($Ok), 'b', "skip (set)");
};

done_testing;
