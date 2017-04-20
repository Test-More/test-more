use strict;
use warnings;

use Test2::Tools::Tiny;
use Test2::API qw/intercept test2_stack/;

plan 4;

my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    require Test::Builder;
};

my $count = 2;
$count += 1 if ref(test2_stack->top->format) eq 'Test2::Formatter::TAP';

is(@warnings, $count, "got warnings");

like(
    $warnings[0],
    qr/Test::Builder was loaded after Test2 initialization, this is not recommended/,
    "Warn about late Test::Builder load"
);

like(
    $warnings[1],
    qr/Formatter Test::Builder::Formatter loaded too late to be used as the global formatter/,
    "Got the formatter warning"
);

if ($count == 3) {
    like(
        $warnings[2],
        qr/The current formatter does not support 'no_header'/,
        "Formatter does not support no_header",
    );
}
else {
    ok(1, "filler");
}
