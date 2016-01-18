use Test2::Bundle::Extended -target => 'Test2::Event::Stamp';

my $events = intercept {
    sub {
        my $ctx = context();

        $ctx->send_event('Stamp', action => 'eat');
        $ctx->send_event('Stamp', action => 'eat', name => 'food');

        $ctx->release;
    }->();
};

isa_ok($events->[0], $CLASS, 'Test2::Event');
isa_ok($events->[1], $CLASS, 'Test2::Event');

is($events->[0]->action, 'eat', "got action");
is($events->[0]->name, 'unknown', "default name");
ok($events->[0]->stamp, "got a stamp");

is($events->[1]->action, 'eat', "got action");
is($events->[1]->name, 'food', "set name");
ok($events->[0]->stamp, "got a stamp");

done_testing;
