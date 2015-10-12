use strict;
use warnings;

use Test::Stream -V1, Compare => '*';

use Test::Stream::Util '-all';

imported_ok qw{
    try protect pkg_to_file

    get_tid USE_THREADS

    get_stash

    sig_to_slot slot_to_sig
    parse_symbol

    term_size

    render_ref
    rtype

    sub_name
    sub_info
    CAN_SET_SUB_NAME
    set_sub_name
};

$! = 100;

for my $protect (\&protect, Test::Stream::Util->can('_manual_protect'), Test::Stream::Util->can('_local_protect')) {
    my $ok = eval { $protect->(sub { die "xxx" }); 1 };
    ok(!$ok, "protect did not capture exception");
    like($@, qr/xxx/, "expected exception");
    ok($! == 100, "\$! did not change");

    local $@ = 'apple';
    $ok = $protect->(sub { 1 });
    like($@, qr/apple/, '$@ has not changed');
    ok($! == 100, "\$! did not change");
}

for my $try (\&try, Test::Stream::Util->can('_manual_try'), Test::Stream::Util->can('_local_try')) {
    $@ = 'foo';
    my ($ok, $err) = $try->(sub { die "xxx" });
    ok(!$ok, "cought exception");
    like( $err, qr/xxx/, "expected exception");
    is($@, 'foo', '$@ is saved');
    ok($! == 100, "\$! did not change");

    ($ok, $err) = $try->(sub { 0 });
    ok($ok, "Success");
    ok(!$err, "no error");
    is($@, 'foo', '$@ is saved');
    ok($! == 100, "\$! did not change");
}

is(pkg_to_file('A::Package::Name'), 'A/Package/Name.pm', "Converted package to file");

{
    local $ENV{TS_TERM_SIZE} = 42;
    is(term_size, 42, "used env var");
    local $ENV{TS_TERM_SIZE} = 1000;
    is(term_size, 1000, "used env var again");
}

if ($INC{'Term/ReadKey.pm'}) {
    local $ENV{'TS_TERM_SIZE'};
    my $size;
    my $ok = eval {
        local $SIG{__WARN__} = sub { 1 };
        ($size) = Term::ReadKey::GetTerminalSize(*STDOUT);
        1;
    };
    is(term_size(), $size, "Got size from Term::ReadKey") if $ok && $size;

    no warnings 'redefine';
    local *Term::ReadKey::GetTerminalSize = sub { 0 };
    is(term_size(), 80, "use default of 80 if Term::ReadKey fails");
}
else {
    local %ENV = %ENV;
    delete $ENV{'TS_TERM_SIZE'};
    is(term_size(), 80, "Default to 80");
}

is(sig_to_slot('&'), 'CODE',   '& -> CODE');
is(sig_to_slot('%'), 'HASH',   '% -> HASH');
is(sig_to_slot('@'), 'ARRAY',  '@ -> ARRAY');
is(sig_to_slot('$'), 'SCALAR', '$ -> SCALAR');
is(sig_to_slot('*'), 'GLOB',   '* -> GLOB');

is(slot_to_sig('CODE'),   '&', 'CODE -> &');
is(slot_to_sig('HASH'),   '%', 'HASH -> %');
is(slot_to_sig('ARRAY'),  '@', 'ARRAY -> @');
is(slot_to_sig('SCALAR'), '$', 'SCALAR -> $');
is(slot_to_sig('GLOB'),   '*', 'GLOB -> *');

is([parse_symbol('Foo')], ['Foo', 'CODE'],   "Parsed CODE w/o sigil");
is([parse_symbol('&Foo')], ['Foo', 'CODE'],   "Parsed CODE");
is([parse_symbol('%Foo')], ['Foo', 'HASH'],   "Parsed HASH");
is([parse_symbol('@Foo')], ['Foo', 'ARRAY'],  "Parsed ARRAY");
is([parse_symbol('$Foo')], ['Foo', 'SCALAR'], "Parsed SCALAR");
is([parse_symbol('*Foo')], ['Foo', 'GLOB'],   "Parsed GLOB");

{
    package Test::A;
    package Test::B;
    use overload '""' => sub { 'A Bee!' };
}
my $ref = {a => 1};
is(render_ref($ref), "$ref", "Matches normal stringification (not blessed)");
like(render_ref($ref), qr/HASH\(0x[0-9A-F]+\)/i, "got address");

bless($ref, 'Test::A');
is(render_ref($ref), "$ref", "Matches normal stringification (blessed)");
like(render_ref($ref), qr/Test::A=HASH\(0x[0-9A-F]+\)/i, "got address and package (no overload)");

bless($ref, 'Test::B');
like(render_ref($ref), qr/Test::B=HASH\(0x[0-9A-F]+\)/i, "got address and package (with overload)");

if (CAN_SET_SUB_NAME) {
    my $sub = sub { 1 };
    like(sub_name($sub), qr/__ANON__$/, "Got sub name (anon)");
    set_sub_name('foo', $sub);
    like(sub_name($sub), qr/foo$/, "Got new sub name")
}

sub named { 'named' }
*unnamed = sub { 'unnamed' };
like(sub_name(\&named), qr/named$/, "got sub name (named)");
like(sub_name(\&unnamed), qr/__ANON__$/, "got sub name (anon)");

like(
    dies { sub_name() },
    qr/sub_name requires a coderef as its only argument/,
    "Need an arg"
);

like(
    dies { sub_name('xxx') },
    qr/sub_name requires a coderef as its only argument/,
    "Need a ref"
);

like(
    dies { sub_name({}) },
    qr/sub_name requires a coderef as its only argument/,
    "Need a code ref"
);

no warnings 'once';
sub empty_named { };   my $empty_named = __LINE__;
*empty_anon = sub { }; my $empty_anon  = __LINE__;

sub one_line_named { 1 };   my $one_line_named = __LINE__;
*one_line_anon = sub { 1 }; my $one_line_anon  = __LINE__;

my $multi_line_named_start = __LINE__ + 1;
sub multi_line_named {
    my $x = 1;
    $x++;
    return $x;
}
my $multi_line_named_end = __LINE__ - 1;
my $multi_line_anon_start = __LINE__ + 1;
*multi_line_anon = sub {
    my $x = 1;
    $x++;
    return $x;
};
my $multi_line_anon_end = __LINE__ - 1;
use warnings 'once';

like(
    sub_info(\&empty_named),
    {
        name       => qr/empty_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&empty_named),
        cobj       => T(),
        start_line => in_set(undef, $empty_named),
        end_line   => in_set(undef, $empty_named),
        lines      => in_set([], [$empty_named, $empty_named]),
        all_lines  => in_set([], [$empty_named]),
    },
    "Got expected results for empty named sub"
);

like(
    sub_info(\&empty_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&empty_anon),
        cobj       => T(),
        start_line => in_set(undef, $empty_anon),
        end_line   => in_set(undef, $empty_anon),
        lines      => in_set([], [$empty_anon, $empty_anon]),
        all_lines  => in_set([], [$empty_anon]),
    },
    "Got expected results for empty anon sub"
);

like(
    sub_info(\&one_line_named),
    {
        name       => qr/one_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&one_line_named),
        cobj       => T(),
        start_line => $one_line_named,
        end_line   => $one_line_named,
        lines      => [$one_line_named, $one_line_named],
        all_lines  => [$one_line_named],
    },
    "Got expected results for one line named sub"
);

like(
    sub_info(\&one_line_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&one_line_anon),
        cobj       => T(),
        start_line => $one_line_anon,
        end_line   => $one_line_anon,
        lines      => [$one_line_anon, $one_line_anon],
        all_lines  => [$one_line_anon],
    },
    "Got expected results for one line anon sub"
);

like(
    sub_info(\&multi_line_named),
    {
        name       => qr/multi_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_named),
        cobj       => T(),
        start_line => $multi_line_named_start,
        end_line   => $multi_line_named_end,
        lines      => [$multi_line_named_start, $multi_line_named_end],
        all_lines  => [$multi_line_named_start + 1, $multi_line_named_start + 2, $multi_line_named_end - 1],
    },
    "Got expected results for multi-line named sub"
);

like(
    sub_info(\&multi_line_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_anon),
        cobj       => T(),
        start_line => $multi_line_anon_start,
        end_line   => $multi_line_anon_end,
        lines      => [$multi_line_anon_start, $multi_line_anon_end],
        all_lines  => [$multi_line_anon_start + 1, $multi_line_anon_start + 2, $multi_line_anon_end - 1],
    },
    "Got expected results for multi-line anon sub"
);

like(
    sub_info(\&multi_line_named, 1, 1000),
    {
        name       => qr/multi_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_named),
        cobj       => T(),
        start_line => 1,
        end_line   => 1000,
        lines      => [1, 1000],
        all_lines  => [1, $multi_line_named_start + 1, $multi_line_named_start + 2, $multi_line_named_end - 1, 1000],
    },
    "Got expected results for multi-line named sub (custom lines)"
);

like(
    sub_info(\&multi_line_anon, 1000, 1),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_anon),
        cobj       => T(),
        start_line => 1,
        end_line   => 1000,
        lines      => [1, 1000],
        all_lines  => [1, $multi_line_anon_start + 1, $multi_line_anon_start + 2, $multi_line_anon_end - 1, 1000],
    },
    "Got expected results for multi-line anon sub (custom lines)"
);

done_testing;
