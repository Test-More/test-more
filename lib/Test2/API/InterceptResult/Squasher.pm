package Test2::API::InterceptResult::Squasher;
use strict;
use warnings;

use Carp qw/croak/;
use List::Util qw/first/;

use Test2::Util::HashBase qw{
    <events

    +down_sig +down_buffer

    +up_into +up_sig +up_clear
};

sub init {
    my $self = shift;

    croak "'events' is a required attribute"  unless $self->{+EVENTS};
}

sub can_squash {
    my $self = shift;
    my ($event) = @_;

    # No info, no squash
    return unless $event->has_info;

    # If the event we would like to merge causes failure on its own then
    # yikes, no merge.
    return if $event->causes_fail;

    # Do not merge up if one of these facets is present.
    return if first { $event->$_ } qw/has_assert has_bailout has_errors has_plan has_subtest/;

    # Signature if we can squash
    return $event->trace_signature;
}

sub process {
    my $self = shift;
    my ($event) = @_;

    return if $self->squash_up($event);
    return if $self->squash_down($event);

    $self->flush_down($event);

    push @{$self->{+EVENTS}} => $event;

    return;
}

sub squash_down {
    my $self = shift;
    my ($event) = @_;

    my $sig = $self->can_squash($event)
        or return;

    unless ($sig) {
        $self->flush_down();
        return;
    }

    if ($self->{+DOWN_SIG} && $self->{+DOWN_SIG} ne $sig) {
        $self->flush_down();
    }

    $self->{+DOWN_SIG} ||= $sig;
    push @{$self->{+DOWN_BUFFER}} => $event;

    return 1;
}

sub flush_down {
    my $self = shift;
    my ($into) = @_;

    my $sig    = delete $self->{+DOWN_SIG};
    my $buffer = delete $self->{+DOWN_BUFFER};

    return unless $buffer && @$buffer;

    my $fsig = $into ? $into->trace_signature : undef;

    if ($fsig && $fsig eq $sig) {
        $self->squash($into, @$buffer);
    }
    else {
        push @{$self->{+EVENTS}} => @$buffer if $buffer;
    }
}

sub clear_up {
    my $self = shift;

    return unless $self->{+UP_CLEAR};

    delete $self->{+UP_INTO};
    delete $self->{+UP_SIG};
    delete $self->{+UP_CLEAR};
}

sub squash_up {
    my $self = shift;
    my ($event) = @_;
    no warnings 'uninitialized';

    $self->clear_up;

    my $into = $self->{+UP_INTO};
    unless ($into) {
        return unless $event->has_assert;
        my $sig = $event->trace_signature or return;

        $self->{+UP_INTO}  = $event;
        $self->{+UP_SIG}   = $sig;
        $self->{+UP_CLEAR} = 0;

        return;
    }

    # Next iteration should clear unless something below changes that
    $self->{+UP_CLEAR} = 1;

    # Only merge into matching trace signatres
    my $sig = $self->can_squash($event);
    return unless $sig eq $self->{+UP_SIG};

    # OK Merge! Do not clear merge in case the return event is also a matching sig diag-only
    $self->{+UP_CLEAR} = 0;

    $self->squash($into, $event);

    return 1;
}

sub squash {
    my $self = shift;
    my ($into, @from) = @_;
    push @{$into->facet_data->{info}} => $_->info for @from;
}

1;
