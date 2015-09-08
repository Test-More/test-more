use Test::Stream qw/-V1 -Tester UTF8/;
use PerlIO;

ok(utf8::is_utf8("癸"), "utf8 pragma is on");

my $layers = { map {$_ => 1} PerlIO::get_layers(STDERR) };
ok($layers->{utf8}, "utf8 is on for STDERR");

$layers = { map {$_ => 1} PerlIO::get_layers(STDOUT) };
ok($layers->{utf8}, "utf8 is on for STDOUT");

my $format = Test::Stream::Sync->stack->top->format;
my $handles = $format->handles;
for my $hn (0 .. @$handles) {
    my $h = $handles->[$hn] || next;
    $layers = { map {$_ => 1} PerlIO::get_layers($h) };
    ok($layers->{utf8}, "utf8 is on for formatter handle $hn");
}

done_testing;
