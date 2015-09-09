use strict;
use warnings;

use Test::Stream qw/-V1 -Tester/;

imported_ok qw{
    grab intercept
    event
    call field prop
    like
    end
    filter_items
};

my $base = __LINE__ + 2;
my $events = intercept {
    ok(1, 'pass');
    ok(0, 'fail');
    diag "foo";
    note "bar";
    done_testing;
};

like(
    $events,
    array {
        event Ok => sub {
            call pass => 1;
            field effective_pass => 1;
            prop line => $base;
        };
        event Ok => sub {
            call pass => 0;
            field effective_pass => 0;
            prop line => $base + 1;
        };
        event Diag => { message => 'foo' };
        event Note => { message => 'bar' };
        event Plan => { max => 2 };
        end;
    },
    "Basic check of events"
);

like(
    $events,
    array {
        filter_items { grep { $_->isa('Test::Stream::Event::Ok') } @_ };
        event Ok => sub {
            call pass => 1;
            field effective_pass => 1;
            prop line => $base;
        };
        event Ok => sub {
            call pass => 0;
            field effective_pass => 0;
            prop line => $base + 1;
        };
        end;
    },
    "Filtering"
);

like(
    $events,
    array {
        event Ok => sub {
            call pass => 1;
            field effective_pass => 1;
            prop line => $base;
            prop file => __FILE__;
            prop package => __PACKAGE__;
            prop subname => 'Test::Stream::Plugin::Core::ok';
            prop trace => 'at ' . __FILE__ . ' line ' . $base;
            prop skip => undef;
            prop todo => undef;
        };
    },
    "METADATA"
);

like(
    intercept {
        todo foo => sub { ok(0, "todo fail") };
        SKIP: { skip 'blah' };
    },
    array {
        event Ok => sub {
            field effective_pass => 1;
            prop todo => 'foo';
            prop skip => undef;
        };
        event Ok => sub {
            field effective_pass => 1;
            prop skip => 'blah';
            prop todo => undef;
        };
        end;
    },
    "Todo and Skip"
);

my $FILE = __FILE__;
like(
    intercept {
        like(
            $events,
            array {
                event Ok => { pass => 1 };
                event Ok => { pass => 1 }; # This is intentionally wrong.
            },
            "Inner check"
        );
    },
    array {
        event Ok => sub {
            call pass => 0;
            call diag => [
                qr/Failed test 'Inner check'/,
            ];
        };
        end;
    },
    "Self-Check"
);

done_testing;
