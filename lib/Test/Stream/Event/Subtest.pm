package Test::Stream::Event::Subtest;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Carp qw/confess/;
use Test::Stream qw/STATE_PASSING STATE_COUNT OUT_STD/;

use Test::Stream::Event(
    base      => 'Test::Stream::Event::Ok',
    accessors => [qw/state events exception/],
);

sub init {
    my $self = shift;

    $self->[REAL_BOOL] = $self->[STATE]->[STATE_PASSING] && $self->[STATE]->[STATE_COUNT];
    $self->[EVENTS] ||= [];

    if (my $le = $self->[EVENTS]->[-1]) {
        my $is_skip = $le->isa('Test::Stream::Event::Plan');
        $is_skip &&= $le->directive;
        $is_skip &&= $le->directive eq 'SKIP';

        if ($is_skip) {
            my $skip = 'all';
            $skip .= ": " . $le->reason if $le->reason;
            # Should be a snapshot now:
            $self->[CONTEXT]->set_skip($skip);
            $self->[REAL_BOOL] = 1;
        }

        $self->[EXCEPTION] = $le if $is_skip || $le->isa('Test::Stream::Event::Bail');
    }

    push @{$self->[DIAG]} => '  No tests run for subtest.'
        unless $self->[EXCEPTION] || $self->[STATE]->[STATE_COUNT];

    $self->SUPER::init();
}

sub to_tap {
    my $self = shift;
    my ($num, $delayed) = @_;

    unless($delayed) {
        return if $self->[EXCEPTION]
               && $self->[EXCEPTION]->isa('Test::Stream::Event::Bail');

        return $self->SUPER::to_tap($num);
    }

    # Subtest final result first
    $self->[NAME] =~ s/$/ {/mg;
    my @out = (
        $self->SUPER::to_tap($num),
        $self->_render_events(@_),
        [OUT_STD, "}\n"],
    );
    $self->[NAME] =~ s/ \{$//mg;
    return @out;
}

sub _render_events {
    my $self = shift;
    my ($num, $delayed) = @_;

    my $idx = 0;
    my @out;
    for my $e (@{$self->events}) {
        next unless $e->can('to_tap');
        $idx++ if $e->isa('Test::Stream::Event::Ok');
        push @out => $e->to_tap($idx, $delayed);
    }

    for my $set (@out) {
        $set->[1] =~ s/^/    /mg;
    }

    return @out;
}

1;
