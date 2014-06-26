use strict;
use warnings;

use Test::More 'modern';

require_ok 'Test::Builder::Formatter';

can_ok('Test::Builder::Formatter', qw/new handle to_handler/);

my $one = Test::Builder::Formatter->new;
isa_ok($one, 'Test::Builder::Formatter');

my $ref = ref $one->to_handler;
is($ref, 'CODE', 'handler returns a coderef');

done_testing;
