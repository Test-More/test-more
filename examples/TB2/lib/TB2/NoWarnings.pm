package TB2::NoWarnings;

use strict;
use warnings;

use Carp;


=head1 NAME

TB2::NoWarnings - Test there are no warnings using TB2.

=head1 SYNOPSIS

    use TB2::NoWarnings;
    use Test::Simple tests => 2;

    ok(1);
    ok(2);

    warn "Blah";  # failure

=head1 DESCRIPTION

This demonstrates how to write a test library which catches 

=head1 CAVEATS

It must be run before the plan is set.  It should throw an error if the
plan is already set, but it doesn't.

=cut

{
    package TB2::NoWarnings::WarningsWatcher;

    use Test::Builder2::Mouse;
    with 'Test::Builder2::EventWatcher';

    has builder  =>
      is                 => 'rw',
      isa                => 'Test::Builder2',
      default            => sub {
          require Test::Builder2;
          return Test::Builder2->singleton;
      };

    has warnings_seen =>
      is                 => 'rw',
      isa                => 'ArrayRef',
      default            => sub { [] };

    has quiet_warnings =>
      is                 => 'rw',
      isa                => 'Bool',
      default            => 0;

    my %event_handlers = (
        'stream start'   => 'accept_stream_start',
        'stream end'     => 'accept_stream_end',
        'set plan'       => 'accept_set_plan'
    );

    sub accept_event {
        my $self  = shift;
        my $event = shift;

        my $event_type = $event->event_type;
        my $handler = $event_handlers{$event_type};
        return unless $handler;

        $self->$handler($event);

        return;
    }

    sub accept_stream_start {
        my $self = shift;

        $SIG{__WARN__} = sub {
            push @{$self->warnings_seen}, @_;
            warn @_ unless $self->quiet_warnings;
        };

        return;
    }

    sub accept_set_plan {
        my $self  = shift;
        my $event = shift;

        my $want = $event->asserts_expected;
        $event->asserts_expected( $want + 1 ) if $want;

        return;
    }

    sub accept_stream_end {
        my $self = shift;

        my $warnings = $self->warnings_seen;

        $self->builder
          ->ok( scalar @$warnings, "no warnings" )
          ->diagnostic([
              warnings => $warnings
          ]);

        remove_warning_handler();

        return;
    }

    sub remove_warning_handler {
        delete $SIG{__WARN__};
    }
}


{
    package TB2::NoWarnings;

    use strict;
    use warnings;

    sub import {
        no_warnings();
    }

    sub no_warnings {
        my $watcher = TB2::NoWarnings::WarningsWatcher->new(
            @_
        );
        $watcher->builder->event_coordinator->add_early_watchers($watcher);

        return;
    }
}

1;
