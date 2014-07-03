use strict;
use warnings;

use Test::More 'modern';

require_ok 'Test::Builder::Result::Diag';

can_ok('Test::Builder::Result::Diag', qw/message/);

my $one = Test::Builder::Result::Diag->new(message => "\nFooo\nBar\nBaz\n");

isa_ok($one, 'Test::Builder::Result::Diag');
isa_ok($one, 'Test::Builder::Result');

is($one->to_tap, "\n# Fooo\n# Bar\n# Baz\n", "Got tap output");

$one->message( "foo bar\n" );
is($one->to_tap, "# foo bar\n", "simple tap");

done_testing;
