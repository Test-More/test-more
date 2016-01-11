use strict;
use warnings;

use Test2::Plugin::UTF8;
use Test2::Tools::Basic qw/ok done_testing/;

use PerlIO;

ok(utf8::is_utf8("癸"), "utf8 pragma is on");

my $layers = { map {$_ => 1} PerlIO::get_layers(STDERR) };
ok($layers->{utf8}, "utf8 is on for STDERR");

$layers = { map {$_ => 1} PerlIO::get_layers(STDOUT) };
ok($layers->{utf8}, "utf8 is on for STDOUT");

my $format = Test2::API::test2_stack->top->format;
my $handles = $format->handles;
for my $hn (0 .. @$handles) {
    my $h = $handles->[$hn] || next;
    $layers = { map {$_ => 1} PerlIO::get_layers($h) };
    ok($layers->{utf8}, "utf8 is on for formatter handle $hn");
}

done_testing;
