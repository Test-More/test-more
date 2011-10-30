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

    has coordinators =>
      is                => 'rw',
      isa               => 'ArrayRef',
      default           => sub { [] }
    ;

    sub accept_event {
        my $self = shift;
        push @{$self->events}, shift;
        push @{$self->coordinators}, shift;
    }
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
