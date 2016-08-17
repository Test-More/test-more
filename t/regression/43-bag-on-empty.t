use Test2::Bundle::Extended;

my $got = intercept {
    my $check = bag {
        item 'a';
        item 'b';
        end();    # Ensure no other elements exist.
    };

    is([], $check, 'All of the elements from bag found!');    # passes but shouldn't
};

like(
    $got,
    array {
        fail_events 'Ok' => sub {
            call pass => 0;
        };
    },
    "Bag check on empty array"
);

done_testing;
