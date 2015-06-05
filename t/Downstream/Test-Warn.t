use strict;
use warnings;

use Test::More;
BEGIN { plan skip_all => "Only tested when releasing" unless $ENV{AUTHOR_TESTING} };
BEGIN { eval { require Test::Warn; 1 } || plan skip_all => ($@ =~ m/^(.*) in \@INC/g)}
use Test::Stream::Tester;
use ok 'Test::Warn';

events_are(
    intercept {
        warning_is { warn 'a' } 'a';
        warning_is { warn 'b' } 'a';

        warnings_are { warn 'a'; warn 'b' } [ 'a', 'b' ];
        warnings_are { warn 'b'; warn 'a' } [ 'a', 'b' ];
        warnings_are { 1 } [];

        warning_like { warn "a xxx a" } qr/xxx/;
        warning_like { warn "a xxx a" } qr/aaa/;
    },
    events {
        filter_events { grep { $_->isa('Test::Stream::Event::Ok') } @_ };
        event Ok => { pass => 1 };
        event Ok => { pass => 0 };

        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
        event Ok => { pass => 1 };

        event Ok => { pass => 1 };
        event Ok => { pass => 0 };
    },
    "Got expected events"
);

done_testing;
