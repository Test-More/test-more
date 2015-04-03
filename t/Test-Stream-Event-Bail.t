use strict;
use warnings;

use Test::More;

use ok 'Test::Stream::Event::Bail';

my $one = Test::Stream::Event::Bail->new(
    context => 'fake',
    created => 'fake',
    reason  => 'foo',
    quiet   => 0,
);

is_deeply(
    $one->to_tap,
    [Test::Stream::Event::Bail::OUT_STD(), "Bail out!  foo\n"],
    "Rendered"
);

$one->set_quiet(1);
ok(!$one->to_tap, "Did not render");

done_testing;
