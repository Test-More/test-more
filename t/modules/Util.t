use strict;
use warnings;

use Test::Stream -V1;

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

done_testing;
