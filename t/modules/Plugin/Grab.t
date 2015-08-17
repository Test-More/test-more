use Test::Stream qw/-Tester Grab/;

imported qw/grab/;

my $grab = grab();
ok(1, "pass");
ok(0, "fail");
my $events = $grab->finish;

is(@$events, 2, "Captured 2 events");

like(
    $events,
    array {
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
    },
    "Got expected events"
);

done_testing;
