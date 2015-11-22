use strict;
use warnings;

use Test::Stream qw/Core Compare/;
use PerlIO;

use Test::Stream::Formatter::TAP;

ok(my $one = Test::Stream::Formatter::TAP->new, "Created a new instance");
isa_ok($one, 'Test::Stream::Formatter::TAP');
my $handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
is($handles->[0], $handles->[2], "First and last handles are the same");
ok($handles->[0] != $handles->[1], "First and second handles are not the same");
my $layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };

if (${^UNICODE} & 2) { # 2 means STDIN
    ok($layers->{utf8}, "'S' is set in PERL_UNICODE, or in -C, honor it, utf8 should be on")
}
else {
    ok(!$layers->{utf8}, "Not utf8 by default")
}

$one->encoding('utf8');
is($one->encoding, 'utf8', "Got encoding");
$handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");

my $two = Test::Stream::Formatter::TAP->new(encoding => 'utf8');
$handles = $two->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");


{
    package My::Event;
    use Test::Stream::Formatter::TAP qw/OUT_STD OUT_ERR/;

    use base 'Test::Stream::Event';
    use Test::Stream::HashBase accessors => [qw/pass name diag note/];

    Test::Stream::Formatter::TAP->register_event(
        __PACKAGE__,
        sub {
            my $self = shift;
            my ($e, $num) = @_;
            return (
                [OUT_STD, "ok $num - " . $e->name . "\n"],
                [OUT_ERR, "# " . $e->name . " " . $e->diag . "\n"],
                [OUT_STD, "# " . $e->name . " " . $e->note . "\n"],
            );
        }
    );
}

my ($std, $err);
open( my $stdh, '>', \$std ) || die "Ooops";
open( my $errh, '>', \$err ) || die "Ooops";

my $it = Test::Stream::Formatter::TAP->new(
    handles => [$stdh, $errh, $stdh],
);

$it->write(
    My::Event->new(
        pass => 1,
        name => 'foo',
        diag => 'diag',
        note => 'note',
        debug => 'fake',
    ),
    55,
);

$it->write(
    My::Event->new(
        pass => 1,
        name => 'bar',
        diag => 'diag',
        note => 'note',
        debug => 'fake',
        nested => 1,
    ),
    1,
);

is($std, <<EOT, "Got expected TAP output to std");
ok 55 - foo
# foo note
    ok 1 - bar
    # bar note
EOT

is($err, <<EOT, "Got expected TAP output to err");
# foo diag
    # bar diag
EOT

$it = undef;
close($stdh);
close($errh);

($std, $err) = ("", "");
open( $stdh, '>', \$std ) || die "Ooops";
open( $errh, '>', \$err ) || die "Ooops";

$it = Test::Stream::Formatter::TAP->new(
    handles    => [$stdh, $errh, $stdh],
    no_diag    => 1,
    no_header  => 1,
    no_numbers => 1,
);

my $dbg = Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'foo']);
my $ok = Test::Stream::Event::Ok->new(pass => 1, name => 'xxx', debug => $dbg);
my $diag = Test::Stream::Event::Diag->new(msg => 'foo', debug => $dbg);
my $plan = Test::Stream::Event::Plan->new(max => 5,     debug => $dbg);
my $bail = Test::Stream::Event::Bail->new(reason => 'foo', nested => 1, debug => $dbg);

$it->write($_, 1) for $ok, $diag, $plan, $bail;

# This checks that the plan, the diag, and the bail are not rendered
is($std, "ok - xxx\n", "Only got the 'ok'");
is($err, "", "no diag");

done_testing;
