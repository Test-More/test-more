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
    package TB2::NoWarnings::WarningsHandler;

    use TB2::Mouse;
    with 'TB2::EventHandler';

    has builder  =>
      is                 => 'rw',
      isa                => 'Test::Builder2',
      default            => sub {
          require Test::Builder2;
          return Test::Builder2->default;
      };

    has warnings_seen =>
      is                 => 'rw',
      isa                => 'ArrayRef',
      default            => sub { [] };

    has quiet_warnings =>
      is                 => 'rw',
      isa                => 'Bool',
      default            => 0;

    sub handle_test_start {
        my $self = shift;

        $SIG{__WARN__} = sub {
            push @{$self->warnings_seen}, @_;
            warn @_ unless $self->quiet_warnings;
        };

        return;
    }

    sub handle_set_plan {
        my $self  = shift;
        my $event = shift;

        my $want = $event->asserts_expected;
        $event->asserts_expected( $want + 1 ) if $want;

        return;
    }

    sub handle_test_end {
        my $self = shift;

        my $warnings = $self->warnings_seen;

        $self->builder
          ->ok( scalar @$warnings, "no warnings" )
          ->diag([
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
        my $handler = TB2::NoWarnings::WarningsHandler->new(
            @_
        );
        $handler->builder->test_state->add_early_handlers($handler);

        return;
    }
}

1;
