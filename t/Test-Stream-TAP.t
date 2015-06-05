use strict;
use warnings;

use Test::Stream;
use PerlIO;

use Test::Stream::TAP;

ok(my $one = Test::Stream::TAP->new, "Created a new instance");
isa_ok($one, 'Test::Stream::TAP');
my $handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
is($handles->[0], $handles->[2], "First and last handles are the same");
ok($handles->[0] != $handles->[1], "First and second handles are not the same");
my $layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok(!$layers->{utf8}, "Not utf8");

$one->encoding('utf8');
$handles = $one->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");

my $two = Test::Stream::TAP->new(encoding => 'utf8');
$handles = $two->handles;
is(@$handles, 3, "Got 3 handles");
$layers = { map {$_ => 1} PerlIO::get_layers($handles->[0]) };
ok($layers->{utf8}, "Now utf8");


{
    package My::Event;
    use Test::Stream::TAP qw/OUT_STD OUT_ERR/;

    use Test::Stream::Event(
        accessors => [qw/pass name diag note/],
    );

    sub to_tap {
        my $self = shift;
        my ($num) = @_;
        return (
            [OUT_STD, "ok $num - " . $self->name . "\n"],
            [OUT_ERR, "# " . $self->name . " " . $self->diag . "\n"],
            [OUT_STD, "# " . $self->name . " " . $self->note . "\n"],
        );
    }
}

my ($std, $err);
open( my $stdh, '>', \$std ) || die "Ooops";
open( my $errh, '>', \$err ) || die "Ooops";

my $it = Test::Stream::TAP->new(
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

done_testing;
