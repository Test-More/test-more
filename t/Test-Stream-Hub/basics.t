use strict;
use warnings;

use Test::Stream;
use Test::Stream::Hub;

{
    package My::Formatter;

    sub new { bless [], shift };

    my $check = 1;
    sub write {
        my $self = shift;
        my ($e, $count) = @_;
        push @$self => $e;
    }
}

{
    package My::Event;

    use Test::Stream::Event(
        accessors => [qw/msg/],
    );
}

my $hub = Test::Stream::Hub->new(
    formatter => My::Formatter->new,
);

sub send_event {
    my ($msg) = @_;
    my $e = My::Event->new(msg => $msg, debug => 'fake');
    $hub->send($e);
}

ok(my $e1 = send_event('foo'), "Created event");
ok(my $e2 = send_event('bar'), "Created event");
ok(my $e3 = send_event('baz'), "Created event");

my $old = $hub->format(My::Formatter->new);

isa_ok($old, 'My::Formatter');
is_deeply(
    $old,
    [$e1, $e2, $e3],
    "Formatter got all events"
);

done_testing;
