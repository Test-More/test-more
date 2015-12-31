use strict;
use warnings;
BEGIN { require "t/tools.pl" };

use Test2::Event();

{
    package My::MockEvent;

    use base 'Test2::Event';
    use Test2::Util::HashBase qw/foo bar baz/;
}

ok(My::MockEvent->can($_), "Added $_ accessor") for qw/foo bar baz/;

my $one = My::MockEvent->new(trace => 'fake');

ok(!$one->causes_fail, "Events do not cause failures by default");

ok(!$one->$_, "$_ is false by default") for qw/increments_count terminate global/;

ok(!$one->get_meta('xxx'), "no meta-data associated for key 'xxx'");

$one->set_meta('xxx', '123');

is($one->get_meta('xxx'), '123', "got meta-data");

is($one->get_meta('xxx', '321'), '123', "did not use default");

is($one->get_meta('yyy', '1221'), '1221', "got the default");

is($one->get_meta('yyy'), '1221', "last call set the value to the default for future use");

done_testing;
