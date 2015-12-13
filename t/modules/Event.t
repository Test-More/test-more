use strict;
use warnings;
use Test2::Tester;

use Test2::Event();

{
    package My::MockEvent;

    use base 'Test2::Event';
    use Test2::Util::HashBase accessors => [qw/foo bar baz/];
}

ok(My::MockEvent->can($_), "Added $_ accessor") for qw/foo bar baz/;

my $one = My::MockEvent->new(trace => 'fake');

ok(!$one->causes_fail, "Events do not cause failures by default");

ok(!$one->$_, "$_ is false by default") for qw/update_state terminate global/;

done_testing;
