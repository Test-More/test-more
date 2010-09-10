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
    package TB2::NoWarnings::Role;

    use Carp;
    use Test::Builder2::Mouse::Role;

    my $Started = 0;    # Is our warning handler set up?
    my @Warnings;       # Storage for the warnings

    # Our warning handler, so we can tell if its still there at the end.
    my $sig_warn = sub {
        push @Warnings, @_;
        warn @_;
    };

    before stream_start => sub {
        $SIG{__WARN__} = $sig_warn;
        $Started = 1;
        return;
    };

    around set_plan => sub {
        my $orig = shift;
        my $self = shift;
        my %args = @_;

        $args{tests}++ if defined $args{tests};

        $self->$orig(%args);
    };

    before stream_end => sub {
        my $self = shift;

        return unless $Started;

        $self->ok( !@Warnings, "no warnings" )->diagnostic([
            warnings => \@Warnings
        ]);

        if( $SIG{__WARN__} eq $sig_warn ) {
            # Remove our warning handler
            delete $SIG{__WARN__} if $SIG{__WARN__} eq $sig_warn;
        }
        else {
            warn "TB2::NoWarnings's \$SIG{__WARN__} handler was replaced, all warnings may not have been caught.\n";
        }

        return;
    };
}

my $builder = Test::Builder2->singleton;

croak "TB2::NoWarnings must be used before the plan is set"
  if $builder->planned_tests;

TB2::NoWarnings::Role->meta->apply( $builder );


# XXX Hack until TB2 can do this itself
END {
    Test::Builder2->singleton->stream_end;
}

1;
