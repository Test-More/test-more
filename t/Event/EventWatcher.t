#!/usr/bin/perl

use strict;
use warnings;

BEGIN { require 't/test.pl'; }

{
    package My::Watcher;

    use Test::Builder2::Mouse;
    with "Test::Builder2::EventWatcher";

    has events =>
      is                => 'rw',
      isa               => 'ArrayRef',
      default           => sub { [] },
    ;

    sub accept_event {
        my $self = shift;
        push @{$self->events}, @_;
    }
}


note "accept_result() passes to accept_event()"; {
    my $ew = My::Watcher->new;

    $ew->accept_event({ foo => 42 });
    $ew->accept_result({ bar => 23 });

    is @{$ew->events},          2,       "events accepted";
    is_deeply $ew->events->[0], { foo => 42 }, "accept_event";
    is_deeply $ew->events->[1], { bar => 23 }, "accept_result pass through";
}


note "can't make a watcher without accept_event()"; {
    ok !eval {
        package My::Bad::Watcher;
        use Test::Builder2::Mouse;
        with "Test::Builder2::EventWatcher";
        sub accept_result {}
    };
    like $@, q['Test::Builder2::EventWatcher' requires the method 'accept_event'];
}


done_testing();
