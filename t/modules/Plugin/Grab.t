use Test::Stream qw/-V1 -Tester Grab/;

imported_ok qw/grab/;

my $grab = grab();
ok(1, "pass");
my $one = $grab->events;
ok(0, "fail");
my $events = $grab->finish;

is(@$one, 1, "Captured 1 event");
is(@$events, 2, "Captured 2 events");

like(
    $one,
    array {
        event Ok => { pass => 1 };
    },
    "Got expected event"
);

like(
    $events,
    array {
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
    },
    "Got expected events"
);

done_testing;
