use Test::Stream -Tester, 'Defer';

use Test::Stream::Hub::Subtest;

my $ran = 0;
my $event;

my $one = Test::Stream::Hub::Subtest->new(
    nested => 3,
);

isa_ok($one, 'Test::Stream::Hub::Subtest', 'Test::Stream::Hub');

{
    my $mock = mock 'Test::Stream::Hub' => (
        override => [
            process => sub { $ran++; (undef, $event) = @_; 'P!' },
        ],
    );

    my $ok = Test::Stream::Event::Ok->new(
        pass => 1,
        name => 'blah',
        debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']),
    );

    def is => ($one->process($ok), 'P!', "processed");
    def is => ($ran, 1, "ran the mocked process");
    def is => ($event, $ok, "got our event");
    def is => ($event->nested, 3, "nested was set");
    def is => ($one->bailed_out, undef, "did not bail");

    $ran = 0;
    $event = undef;

    my $bail = Test::Stream::Event::Bail->new(
        message => 'blah',
        debug => Test::Stream::DebugInfo->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']),
    );

    def is => ($one->process($bail), 'P!', "processed");
    def is => ($ran, 1, "ran the mocked process");
    def is => ($event, $bail, "got our event");
    def is => ($event->nested, 3, "nested was set");
    def is => ($one->bailed_out, $event, "bailed");
}

do_def;

$ran = 0;

TS_SUBTEST_WRAPPER: {
    $ran++;
    $one->terminate(100);
    $ran++;
}

is($ran, 1, "did not get past the terminate");

done_testing;
