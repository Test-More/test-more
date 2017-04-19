use strict;
use warnings;
use Test2::Tools::Tiny;
use Test2::Event::Output;
use Test2::Util::Trace;

my $output = Test2::Event::Output->new(
    trace       => Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message     => 'foo',
    stream_name => 'whatever',
);

is($output->summary, 'foo', "summary is just message");

$output = Test2::Event::Output->new(
    trace => Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => undef,
    stream_name => 'whatever',
);

is($output->message, 'undef', "set undef message to undef");
is($output->summary, 'undef', "summary is just message even when undef");

$output = Test2::Event::Output->new(
    trace => Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__]),
    message => {},
    stream_name => 'whatever',
    diagnostics => 1,
);

like($output->message, qr/^HASH\(.*\)$/, "stringified the input value");

ok($output->diagnostics, "Diagnostics can be set");

like(
    exception { Test2::Event::Output->new() },
    qr/^'stream_name' is required/,
    "Must provide a stream name"
);

done_testing;
