use strict;
use warnings;

use Test::Stream;

use Test::Stream::Util '-all';

imported qw{
    try protect pkg_to_file

    get_tid USE_THREADS

    get_stash

    sig_to_slot slot_to_sig
    parse_symbol

    term_size
};

$! = 100;

my $ok = eval { protect { die "xxx" }; 1 };
ok(!$ok, "protect did not capture exception");
like($@, qr/xxx/, "expected exception");

ok($! == 100, "\$! did not change");

$@ = 'foo';
($ok, my $err) = try { die "xxx" };
ok(!$ok, "cought exception");
like( $err, qr/xxx/, "expected exception");
is($@, 'foo', '$@ is saved');
ok($! == 100, "\$! did not change");

is(pkg_to_file('A::Package::Name'), 'A/Package/Name.pm', "Converted package to file");

{
    local $ENV{TS_TERM_SIZE} = 42;
    is(term_size, 42, "used env var");
    local $ENV{TS_TERM_SIZE} = 1000;
    is(term_size, 1000, "used env var again");
}

if ($INC{'Term/ReadKey.pm'}) {
    local $ENV{'TS_TERM_SIZE'} = undef;
    my ($size) = Term::ReadKey::GetTerminalSize(*STDOUT);
    is(term_size(), $size, "Got size from Term::ReadKey") if $size;

    no warnings 'redefine';
    local *Term::ReadKey::GetTerminalSize = sub { 0 };
    is(term_size(), 80, "use default of 80 if Term::ReadKey fails") if $size;
}
else {
    local $ENV{'TS_TERM_SIZE'} = undef;
    is(term_size(), 80, "Default to 80");
}

done_testing;
