use Test::Stream -V1, -Tester;
use Test::Stream::DebugInfo;

like(
    dies { 'Test::Stream::DebugInfo'->new() },
    qr/Frame is required/,
    "got error"
);

my $one = 'Test::Stream::DebugInfo'->new(frame => ['Foo::Bar', 'foo.t', 5, 'Foo::Bar::foo']);
isa_ok($one, 'Test::Stream::DebugInfo');
is($one->frame,  ['Foo::Bar', 'foo.t', 5, 'Foo::Bar::foo'], "Got frame");
is([$one->call], ['Foo::Bar', 'foo.t', 5, 'Foo::Bar::foo'], "Got call");
is($one->package, 'Foo::Bar',      "Got package");
is($one->file,    'foo.t',         "Got file");
is($one->line,    5,               "Got line");
is($one->subname, 'Foo::Bar::foo', "got subname");

is($one->trace, "at foo.t line 5", "got trace");
$one->set_detail("yo momma");
is($one->trace, "yo momma", "got detail for trace");
$one->set_detail(undef);

ok(!eval { $one->throw('I died'); 1 }, "threw exception");
is($@, "I died at foo.t line 5.\n", "got exception");

my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    $one->alert('I cried');
}

like(
    warns { $one->alert('I cried') },
    [ qr/I cried at foo\.t line 5/ ],
    "alter() warns"
);

my $snap = $one->snapshot;
is($snap, $one, "identical");
ok($snap != $one, "Not the same instance");

ok(!$one->no_diag, "yes diag");
ok(!$one->no_fail, "yes fail");

$one->set_parent_todo(1);
ok($one->no_diag, "no diag");
ok(!$one->no_fail, "yes fail");

$one->set_parent_todo(0);
$one->set_todo(1);
ok($one->no_diag, "no diag");
ok($one->no_fail, "no fail");

$one->set_todo(undef);
like(
    warning { $one->set_skip(1) },
    qr/Use of 'skip' attribute for DebugInfo is deprecated/,
    "Got expected warning for deprecated 'skip' attribute"
);
ok($one->no_diag, "no diag");
ok($one->no_fail, "no fail");

done_testing;
