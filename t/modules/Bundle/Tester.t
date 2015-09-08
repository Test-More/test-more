use Test::Stream -V1, -Tester;

is(
    [Test::Stream::Bundle::Tester->plugins],
    [
        qw/Intercept Grab LoadPlugin Context/,
        Compare => ['-all'],
    ],
    "All plugins listed"
);

imported qw/
    intercept grab
    load_plugin
    context
    is like
    match mismatch check
    hash array object meta
    item field call prop
    end filter_items
    T F D DNE
    event
/;

is(
    intercept { ok(1, "pass") },
    array {
        event Ok => sub {
            call pass => T;
            call name => 'pass';
        };
        end;
    },
    "Intercepted an event"
);

done_testing;
