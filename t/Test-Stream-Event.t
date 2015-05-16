use strict;
use warnings;

use Test::Stream;
use Test::More;

use ok 'Test::Stream::Event';

can_ok('Test::Stream::Event', qw/debug nested/);

my $ok = eval { Test::Stream::Event->new(); 1 };
my $err = $@;
ok(!$ok, "Died");
like($err, qr/No debug info provided/, "Need debug info");

{
    package My::MockEvent;
    use Test::Stream::Event(
        accessors => [qw/foo bar baz/],
    );
}

can_ok('My::MockEvent', qw/foo bar baz/);
isa_ok('My::MockEvent', 'Test::Stream::Event');

my $one = My::MockEvent->new(debug => 'fake');

done_testing;
